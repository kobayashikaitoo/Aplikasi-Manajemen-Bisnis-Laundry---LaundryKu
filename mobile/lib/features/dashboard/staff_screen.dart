import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'staff_providers.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  void _openAddStaffSheet() {
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
        child: const _AddStaffForm(),
      ),
    );
  }

  Future<void> _confirmToggleStatus(StaffModel staff) async {
    final willDeactivate = staff.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willDeactivate ? 'Nonaktifkan Pegawai?' : 'Aktifkan Pegawai?'),
        content: Text(
          willDeactivate
              ? 'Akun ${staff.name} tidak akan bisa login ke aplikasi kasir. Data transaksi lama tetap tersimpan utuh.'
              : 'Akun ${staff.name} akan dapat login kembali untuk melayani pesanan kasir.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate ? AppColors.danger : AppColors.success,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willDeactivate ? 'Ya, Nonaktifkan' : 'Ya, Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await ref.read(staffProvider.notifier).toggleStatus(staff.id);
      if (mounted) {
        if (ok) {
          showSnack(
            context,
            willDeactivate
                ? 'Akun ${staff.name} berhasil dinonaktifkan.'
                : 'Akun ${staff.name} berhasil diaktifkan.',
          );
        } else {
          showSnack(context, 'Gagal mengubah status pegawai.', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Kelola Pegawai / Kasir',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(staffProvider.notifier).fetchStaff(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStaffSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text(
          'Tambah Pegawai',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      body: staffAsync.when(
        loading: () => const LoadingView(message: 'Memuat data pegawai...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(staffProvider.notifier).fetchStaff(),
        ),
        data: (staffList) {
          return RefreshIndicator(
            onRefresh: () => ref.read(staffProvider.notifier).fetchStaff(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFB2D8DC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hanya pemilik yang dapat membuat dan menonaktifkan akun kasir outlet. Pegawai tidak dapat mendaftar mandiri.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (staffList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyView(
                      icon: Icons.people_outline_rounded,
                      message: 'Belum ada pegawai. Klik "Tambah Pegawai" untuk membuat akun kasir.',
                    ),
                  )
                else
                  ...staffList.map((s) => _buildStaffCard(s)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaffCard(StaffModel staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: staff.isActive ? AppColors.border : const Color(0xFFFCA5A5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: staff.isActive
                    ? AppColors.primaryLight
                    : const Color(0xFFFEE2E2),
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'P',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: staff.isActive ? AppColors.primary : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peran: Kasir / Staf Outlet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: staff.isActive
                      ? AppColors.successLight
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  staff.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: staff.isActive ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  staff.email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (staff.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  staff.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _confirmToggleStatus(staff),
              icon: Icon(
                staff.isActive
                    ? Icons.person_off_outlined
                    : Icons.person_outline_rounded,
                size: 15,
              ),
              label: Text(
                staff.isActive ? 'Nonaktifkan Akun' : 'Aktifkan Akun',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    staff.isActive ? AppColors.danger : AppColors.success,
                side: BorderSide(
                  color: staff.isActive ? AppColors.danger : AppColors.success,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStaffForm extends ConsumerStatefulWidget {
  const _AddStaffForm();

  @override
  ConsumerState<_AddStaffForm> createState() => _AddStaffFormState();
}

class _AddStaffFormState extends ConsumerState<_AddStaffForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ok = await ref.read(staffProvider.notifier).createStaff(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          phone: _phoneCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop();
      showSnack(context, 'Akun pegawai ${_nameCtrl.text.trim()} berhasil dibuat!');
    } else {
      showSnack(context, 'Gagal membuat akun pegawai. Pastikan surel belum dipakai.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Tambah Pegawai / Kasir',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Akun baru akan langsung aktif dan bertugas di cabang Anda.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Nama
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap Pegawai',
              hintText: 'Contoh: Rina Wahyuni',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 12),

          // Email
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Surel (Email Login)',
              hintText: 'kasir@laundryku.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Surel wajib diisi';
              if (!v.contains('@')) return 'Format surel tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Telepon
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor Telepon',
              hintText: '081234567890',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nomor telepon wajib diisi' : null,
          ),
          const SizedBox(height: 12),

          // Kata Sandi
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Kata Sandi Awal',
              hintText: 'Minimal 8 karakter',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 8 ? 'Minimal 8 karakter' : null,
          ),
          const SizedBox(height: 20),

          // Tombol Simpan
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Buat Akun Pegawai',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
