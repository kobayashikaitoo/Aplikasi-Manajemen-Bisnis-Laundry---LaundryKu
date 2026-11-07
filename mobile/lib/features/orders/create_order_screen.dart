import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import 'data/models.dart';
import 'order_detail_screen.dart';
import 'orders_providers.dart';

enum DeliveryMethod { jemputAntar, antarSendiri }

class _CapturedPhoto {
  final XFile file;
  final Uint8List bytes;

  _CapturedPhoto({required this.file, required this.bytes});
}

class _DraftItem {
  final ServiceModel service;
  double quantity;

  _DraftItem({required this.service, double? quantity})
      : quantity = quantity ?? (service.unit == 'kg' ? service.minOrder : 1.0);

  int get unitPrice => service.price;
  int get subtotal => (unitPrice * quantity).round();
  String get unitLabel => switch (service.unit) {
        'kg' => 'kg',
        'pcs' => 'pcs',
        'pasang' => 'pasang',
        'm2' => 'm²',
        _ => service.unit,
      };
}

class CreateOrderScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const CreateOrderScreen({super.key, this.initialCategory});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final List<_DraftItem> _items = [];
  final _discountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CustomerModel? _customer;
  bool _saving = false;

  // Role Pelanggan specific states (Mockup Image 2 & 3)
  String _selectedCategory = 'Kiloan';
  double _kiloanWeight = 4.5; // Default seperti di mockup (4,5 kg)
  DeliveryMethod _deliveryMethod = DeliveryMethod.jemputAntar;
  String _selectedTimeSlot = '10.00–12.00';
  DateTime _selectedDate = DateTime.now();
  String _address = '';

  static const _conditionTags = ['Noda', 'Sobek', 'Kancing hilang', 'Tidak ada cacat'];
  final Set<String> _selectedTags = {};
  final List<_CapturedPhoto> _capturedPhotos = [];

  final List<String> _timeSlots = [
    '08.00–10.00',
    '10.00–12.00',
    '13.00–15.00',
    '15.00–17.00',
    '17.00–19.00',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && user.isCustomer) {
        // Auto-isi customer dari sesi login; customerId bisa null pada akun baru
        // sebelum backend berhasil membuat profil Customer — backend akan auto-create saat POST /orders
        setState(() {
          if (user.customerId != null) {
            _customer = CustomerModel(
              id: user.customerId!,
              name: user.name,
              phone: user.phone,
              pointBalance: user.pointBalance,
            );
          } else {
            // Tandai bahwa ini pelanggan sendiri agar validasi lokal tidak terhalang;
            // backend OrderController akan resolve customer_id dari token
            _customer = CustomerModel(
              id: 0, // placeholder; OrderController meresolve dari token
              name: user.name,
              phone: user.phone,
              pointBalance: user.pointBalance,
            );
          }
          _address = (user.address != null && user.address!.trim().isNotEmpty)
              ? user.address!
              : 'Jl. Melati No. 12, Denpasar';
        });
      }
    });
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _subtotal => _items.fold(0, (sum, it) => sum + it.subtotal);
  int get _discount {
    final v = int.tryParse(_discountCtrl.text.trim()) ?? 0;
    return v.clamp(0, _subtotal);
  }

  int get _total => (_subtotal - _discount).clamp(0, _subtotal);
  double get _discountPercent => _subtotal == 0 ? 0 : _discount / _subtotal;
  bool get _discountNeedsOwner =>
      _discountPercent > 0.10 && !(ref.read(authProvider).user?.isOwner ?? false);

  void _syncKiloanDraft(List<ServiceModel> services) {
    if (services.isEmpty) return;
    final kiloanService = services.firstWhere(
      (s) => s.unit.toLowerCase() == 'kg' || s.name.toLowerCase().contains('kiloan'),
      orElse: () => services.first,
    );

    final idx = _items.indexWhere((it) => it.service.id == kiloanService.id);
    if (idx >= 0) {
      _items[idx].quantity = _kiloanWeight;
    } else {
      _items.clear();
      _items.add(_DraftItem(service: kiloanService, quantity: _kiloanWeight));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _capturedPhotos.add(_CapturedPhoto(file: picked, bytes: bytes));
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          'Tidak dapat mengakses ${source == ImageSource.camera ? "kamera" : "galeri"}: $e',
          isError: true,
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
  }

  Future<void> _pickCustomer() async {
    try {
      final customers = await ref.read(customersProvider.future);
      _showCustomerSheet(customers);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _showCustomerSheet(List<CustomerModel> customers) async {
    final selected = await showModalBottomSheet<CustomerModel>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih Pelanggan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            if (customers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada pelanggan terdaftar.'),
              ),
            ...customers.map((c) => ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 18)),
                  title: Text(c.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${c.phone} · ${c.pointBalance} poin',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, c),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _customer = selected);
  }

  Future<void> _addService() async {
    List<ServiceModel> services;
    try {
      services = await ref.read(servicesProvider.future);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      return;
    }
    if (!mounted) return;
    if (services.isEmpty) {
      showSnack(context, 'Daftar layanan belum termuat.', isError: true);
      return;
    }
    final picked = await showModalBottomSheet<ServiceModel>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('+ Layanan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            ...services.map((s) => ListTile(
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                      '${Formatters.rupiah(s.price)} / ${s.unit == 'm2' ? 'm²' : s.unit} · estimasi ${s.estimateDurationHours} jam',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        final existing = _items.where((e) => e.service.id == picked.id);
        if (existing.isNotEmpty) {
          existing.first.quantity += picked.unit == 'kg' ? 0.5 : 1.0;
        } else {
          _items.add(_DraftItem(service: picked));
        }
      });
    }
  }

  void _changeQty(_DraftItem item, double delta) {
    setState(() {
      final min = item.service.unit == 'kg' ? item.service.minOrder : 1.0;
      final step = item.service.unit == 'kg' ? 0.5 : 1.0;
      final next = (item.quantity + delta * step);
      item.quantity = next < min ? min : (next * 10).roundToDouble() / 10;
    });
  }

  void _showEditAddressDialog() {
    final addrCtrl = TextEditingController(text: _address);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ubah Alamat Penjemputan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan alamat lengkap Anda agar kurir mudah menemukan lokasi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addrCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Contoh: Jl. Melati No. 12, Denpasar, Bali',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newAddr = addrCtrl.text.trim();
                if (newAddr.isNotEmpty) {
                  setState(() => _address = newAddr);
                  ref.read(apiClientProvider).put('/auth/address', data: {'address': newAddr});
                }
                Navigator.pop(ctx);
              },
              child: const Text('Gunakan Alamat Ini'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_customer == null) {
      final user = ref.read(authProvider).user;
      if (user != null && user.isCustomer) {
        _customer = CustomerModel(
          id: user.customerId ?? 0,
          name: user.name,
          phone: user.phone,
          pointBalance: user.pointBalance,
        );
      }
    }

    if (_customer == null) {
      showSnack(context, 'Pilih pelanggan terlebih dahulu.', isError: true);
      return;
    }
    if (_items.isEmpty) {
      showSnack(context, 'Tambahkan minimal satu layanan.', isError: true);
      return;
    }
    if (_discountNeedsOwner) {
      showSnack(
          context,
          'Diskon di atas 10% memerlukan otorisasi pemilik. Kurangi diskon atau minta pemilik.',
          isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final key = 'ord-${DateTime.now().millisecondsSinceEpoch}-${_customer!.id}';

      // Format keterangan metode pengiriman
      final dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDate);
      final deliveryNote = _deliveryMethod == DeliveryMethod.jemputAntar
          ? 'Metode: Jemput & Antar · Alamat: $_address · Jadwal: $dateStr, $_selectedTimeSlot'
          : 'Metode: Antar Sendiri ke Outlet Cabang Utama';

      final combinedNotes = [
        deliveryNote,
        if (_selectedTags.isNotEmpty) 'Kondisi: ${_selectedTags.join(', ')}',
        if (_notesCtrl.text.trim().isNotEmpty) _notesCtrl.text.trim(),
      ].join(' · ');

      final order = await ref.read(laundryRepositoryProvider).createOrder(
            customerId: _customer!.id,
            items: _items
                .map((e) => {
                      'service_id': e.service.id,
                      'quantity': e.quantity,
                    })
                .toList(),
            discountAmount: _discount,
            notes: combinedNotes,
            idempotencyKey: key,
          );

      // Upload foto kondisi awal pakaian jika ada yang ditambahkan (Mockup Image 3 / P-06)
      if (_capturedPhotos.isNotEmpty) {
        for (final photo in _capturedPhotos) {
          try {
            final dataUri = 'data:image/jpeg;base64,${base64Encode(photo.bytes)}';
            await ref.read(laundryRepositoryProvider).uploadPhoto(
                  order.id,
                  dataUri,
                  photoType: 'initial',
                );
          } catch (_) {}
        }
      }

      if (!mounted) return;
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      );
      showSnack(context, 'Pesanan ${order.orderNo} berhasil dibuat!');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final isCustomerRole = currentUser?.isCustomer ?? false;
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isCustomerRole ? 'Pesan Laundry' : 'Order Baru',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: servicesAsync.when(
        loading: () => const LoadingView(message: 'Memuat data layanan...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(servicesProvider),
        ),
        data: (services) {
          if (isCustomerRole && _items.isEmpty && services.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _syncKiloanDraft(services));
              }
            });
          }

          return isCustomerRole
              ? _buildCustomerView(services)
              : _buildStaffView(services);
        },
      ),
    );
  }

  // ============================================================================
  // TAMPILAN ROLE PELANGGAN (Sesuai Mockup Image 2 & Image 3)
  // ============================================================================
  Widget _buildCustomerView(List<ServiceModel> services) {
    final dateStr = DateFormat('EEEE, d MMM', 'id_ID').format(_selectedDate);
    final ordersAsync = ref.watch(ordersListProvider);

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      children: [
        // 1. Selector Jenis Layanan (Kiloan, Satuan, Sepatu, Karpet)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Jenis layanan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: ['Kiloan', 'Satuan', 'Sepatu', 'Karpet'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      if (cat == 'Kiloan') {
                        _syncKiloanDraft(services);
                      } else {
                        final matched = services.where(
                          (s) => s.name.toLowerCase().contains(cat.toLowerCase()),
                        ).toList();
                        _items.clear();
                        if (matched.isNotEmpty) {
                          _items.add(_DraftItem(service: matched.first, quantity: 1.0));
                        }
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? AppColors.primary : AppColors.border,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Banner Pesanan Aktif (Mockup Image 2)
        ordersAsync.when(
          data: (orders) {
            final activeOrders = orders.where((o) =>
                o.status != 'Selesai' &&
                o.status != 'Dibatalkan' &&
                o.status != 'Tidak Diambil').toList();
            if (activeOrders.isEmpty) return const SizedBox.shrink();

            final active = activeOrders.first;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pesanan aktif',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        active.orderNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sedang ${active.status.toLowerCase()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active.completedAt != null
                        ? 'Estimasi selesai: ${Formatters.dateTimeWita(active.completedAt)}'
                        : 'Estimasi pengerjaan 1-2 hari kerja',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMiniStatusStepper(active.status),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: active.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Lihat linimasa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // 3. Kartu Perkiraan Berat (Mockup Image 2)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCategory == 'Kiloan' ? 'Perkiraan berat' : 'Jumlah item',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedCategory == 'Kiloan'
                          ? 'Minimum 1 kg · timbang final di outlet'
                          : 'Dihitung per satuan item pakaian',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_selectedCategory == 'Kiloan') {
                        if (_kiloanWeight > 1.0) {
                          setState(() {
                            _kiloanWeight = ((_kiloanWeight - 0.5) * 10).roundToDouble() / 10;
                            if (_kiloanWeight < 1.0) _kiloanWeight = 1.0;
                            _syncKiloanDraft(services);
                          });
                        }
                      } else if (_items.isNotEmpty && _items.first.quantity > 1) {
                        _changeQty(_items.first, -1);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.remove, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      _selectedCategory == 'Kiloan'
                          ? '${_kiloanWeight.toStringAsFixed(1).replaceAll('.', ',')} kg'
                          : '${_items.isNotEmpty ? _items.first.quantity.toInt() : 1} pcs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (_selectedCategory == 'Kiloan') {
                        setState(() {
                          _kiloanWeight = ((_kiloanWeight + 0.5) * 10).roundToDouble() / 10;
                          _syncKiloanDraft(services);
                        });
                      } else if (_items.isNotEmpty) {
                        _changeQty(_items.first, 1);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 4. KARTU FITUR INTI: SEGMENTED METODE JEMPUT & ANTAR VS ANTAR SENDIRI (Mockup Image 2)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _deliveryMethod = DeliveryMethod.jemputAntar),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _deliveryMethod == DeliveryMethod.jemputAntar
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _deliveryMethod == DeliveryMethod.jemputAntar
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Jemput & antar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: _deliveryMethod == DeliveryMethod.jemputAntar
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _deliveryMethod == DeliveryMethod.jemputAntar
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _deliveryMethod = DeliveryMethod.antarSendiri),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _deliveryMethod == DeliveryMethod.antarSendiri
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _deliveryMethod == DeliveryMethod.antarSendiri
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Antar sendiri',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: _deliveryMethod == DeliveryMethod.antarSendiri
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _deliveryMethod == DeliveryMethod.antarSendiri
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              if (_deliveryMethod == DeliveryMethod.jemputAntar) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rumah · $_address',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jarak ke outlet 4,2 km',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _showEditAddressDialog,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Ubah',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Jadwal jemput · $dateStr',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    ..._timeSlots.map((slot) {
                      final isSelected = _selectedTimeSlot == slot;
                      return InkWell(
                        onTap: () => setState(() => _selectedTimeSlot = slot),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 96) / 3,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            slot,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: _pickCustomDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 96) / 3,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tanggal lain',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_deliveryMethod == DeliveryMethod.antarSendiri) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LaundryKu Cabang Utama',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jl. Pendidikan No. 45, Denpasar, Bali',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jam buka: 08.00 – 20.00 WITA',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Silakan bawa cucian Anda langsung ke outlet. Kasir kami akan menimbang dan mencetak nota secara langsung.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 5. KONDISI AWAL PAKAIAN & UNGGAH FOTO (Sesuai Mockup Image 3)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan badge "Foto wajib"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kondisi awal pakaian',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _capturedPhotos.isNotEmpty
                          ? '${_capturedPhotos.length} Foto'
                          : 'Foto wajib',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chips Tag Kondisi Pakaian
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _conditionTags.map((t) {
                  final isSel = _selectedTags.contains(t);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (t == 'Tidak ada cacat') {
                          _selectedTags.clear();
                          _selectedTags.add(t);
                        } else {
                          _selectedTags.remove('Tidak ada cacat');
                          if (isSel) {
                            _selectedTags.remove(t);
                          } else {
                            _selectedTags.add(t);
                          }
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFE8F3F5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppColors.primary : AppColors.border,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSel) ...[
                            const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            t,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                              color: isSel ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Seksi Unggah Foto Kondisi Awal (Mockup Image 3)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tombol Kamera (Dashed Border)
                  InkWell(
                    onTap: () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: _DashedBorderPainter(
                        color: AppColors.primary,
                        strokeWidth: 1.5,
                        radius: 14,
                      ),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Tombol Galeri Foto
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F3F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD3E8EC)),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Teks Keterangan Bukti Klaim
                  Expanded(
                    child: Text(
                      'Foto kondisi awal tersimpan sebagai bukti klaim.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),

              // Galeri Pratinjau Foto yang Diambil
              if (_capturedPhotos.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedPhotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final photo = _capturedPhotos[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              photo.bytes,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 14),

              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan tambahan (opsional)',
                  hintText: 'Contoh: baju putih tolong dipisah, kancing cadangan ada di kantong',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 6. Ringkasan Biaya (Mockup Image 2)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _items.isNotEmpty
                        ? '${_items.first.service.name} ${_selectedCategory == 'Kiloan' ? '${_kiloanWeight.toStringAsFixed(1).replaceAll('.', ',')} kg' : '${_items.first.quantity.toInt()} pcs'} × ${Formatters.rupiah(_items.first.unitPrice)}'
                        : 'Layanan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    Formatters.rupiah(_subtotal),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _deliveryMethod == DeliveryMethod.jemputAntar
                        ? 'Biaya jemput & antar'
                        : 'Biaya pengantaran',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _deliveryMethod == DeliveryMethod.jemputAntar
                        ? 'Gratis (Promo)'
                        : 'Rp0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    Formatters.rupiah(_total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 7. Tombol Pesan Sekarang
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pesan Laundry Sekarang',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper Mini Progress Bar Stepper untuk Pesanan Aktif
  Widget _buildMiniStatusStepper(String currentStatus) {
    const steps = ['Diterima', 'Dicuci', 'Disetrika', 'Siap', 'Selesai'];
    int currentIndex = steps.indexOf(currentStatus);
    if (currentIndex < 0) {
      if (currentStatus == 'Ditimbang') {
        currentIndex = 0;
      } else if (currentStatus == 'Diambil' || currentStatus == 'Lunas') {
        currentIndex = 3;
      } else {
        currentIndex = 0;
      }
    }

    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            final isReached = i <= currentIndex;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 4),
                height: 4,
                decoration: BoxDecoration(
                  color: isReached ? Colors.white : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.map((s) {
            final isCurrent = s == currentStatus;
            return Text(
              s,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.65),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================================
  // TAMPILAN ROLE PEGAWAI / KASIR (Form Order Kasir Lengkap)
  // ============================================================================
  Widget _buildStaffView(List<ServiceModel> services) {
    final customer = _customer;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        SectionCard(
          onTap: _pickCustomer,
          child: Row(
            children: [
              const Icon(Icons.person_search_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: customer == null
                    ? const Text('Pilih pelanggan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('${customer.phone} · ${customer.pointBalance} poin',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
              ),
              Icon(customer == null ? Icons.chevron_right_rounded : Icons.refresh_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
        const SectionHeader(title: 'Item layanan'),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Belum ada layanan dipilih. Tekan "+ Layanan".',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        ..._items.map((it) => SectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(it.service.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Text(Formatters.rupiah(it.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  Text(
                      '${Formatters.rupiah(it.unitPrice)} / ${it.unitLabel}${it.service.unit == 'kg' ? ' · bulat 0,1 kg' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _changeQty(it, -1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text(
                          it.service.unit == 'kg'
                              ? '${it.quantity.toStringAsFixed(1)} ${it.unitLabel}'
                              : '${it.quantity.toInt()} ${it.unitLabel}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      IconButton.filledTonal(
                        onPressed: () => _changeQty(it, 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: _addService,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Layanan'),
            ),
          ),
        ),
        const SectionHeader(title: 'Kondisi awal pakaian'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditionTags
                .map((t) => FilterChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      selected: _selectedTags.contains(t),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      onSelected: (on) => setState(
                          () => on ? _selectedTags.add(t) : _selectedTags.remove(t)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: pisahkan baju berwarna',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            children: [
              _row('Subtotal', _subtotal),
              const SizedBox(height: 6),
              TextField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Diskon (Rp)',
                  isDense: true,
                  prefixIcon: const Icon(Icons.local_offer_rounded, size: 18),
                  helperText: _discountNeedsOwner
                      ? 'Diskon di atas 10% perlu otorisasi pemilik'
                      : 'Diskon di atas 10% memerlukan otorisasi pemilik.',
                  helperStyle: TextStyle(
                      color: _discountNeedsOwner ? AppColors.danger : AppColors.textMuted,
                      fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              _row('Total', _total, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan & buat nota'),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, int amount, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(Formatters.rupiah(amount),
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}

/// Custom painter untuk render garis putus-putus (Dashed Border) pada tombol Kamera
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      const double dashWidth = 5.0;
      const double dashSpace = 3.5;
      while (distance < metric.length) {
        final double len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
