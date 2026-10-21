import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../dashboard/audit_log_screen.dart';
import '../dashboard/cashflow_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/services_screen.dart';
import '../dashboard/staff_screen.dart';
import 'auth_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  // Notification toggle states
  bool _notifStatusCucian = true;
  bool _notifPengingatAmbil = true;
  bool _notifPromo = false;
  bool _notifStaffTask = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final roleLabel = switch (user.role) {
      'pemilik' => 'Pemilik (Owner)',
      'pegawai' => 'Pegawai / Kasir',
      _ => 'Pelanggan (Member)',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Akun',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 48),
        children: [
          // 1. Profil Hero Card
          _buildProfileHeader(user, roleLabel),
          const SizedBox(height: 20),

          // 2. MENU PEMILIK (TETAP UTUH SESUAI ASLINYA)
          if (user.isOwner) ...[
            const SectionHeader(title: 'Menu pemilik'),
            _tile(context, Icons.dashboard_rounded, 'Dashboard', () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DashboardScreen()));
            }),
            _tile(context, Icons.people_rounded, 'Kelola Pegawai / Kasir', () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StaffScreen()));
            }),
            _tile(context, Icons.sell_rounded, 'Layanan & Harga', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServicesScreen()));
            }),
            _tile(context, Icons.swap_vert_rounded, 'Cashflow', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CashflowScreen()));
            }),
            _tile(context, Icons.fact_check_rounded, 'Audit Log', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()));
            }),
          ],

          // 3. MENU ROLE PELANGGAN (LENGKAP SESUAI WIREFRAME HALAMAN 23)
          if (user.isCustomer) ...[
            const SectionHeader(title: 'AKUN'),
            _tile(context, Icons.person_outline_rounded, 'Ubah data profil', () {
              _showEditProfileDialog(context, user);
            }),
            _tile(context, Icons.location_on_outlined, 'Alamat tersimpan', () {
              _showSavedAddressDialog(context, user);
            }),
            _tile(context, Icons.lock_outline_rounded, 'Ubah kata sandi', () {
              _showChangePasswordDialog(context);
            }),

            const SizedBox(height: 12),
            const SectionHeader(title: 'NOTIFIKASI'),
            _switchTile(
              title: 'Status cucian',
              subtitle: 'Selesai, diantar, dan info klaim',
              value: _notifStatusCucian,
              onChanged: (val) => setState(() => _notifStatusCucian = val),
            ),
            _switchTile(
              title: 'Pengingat pengambilan',
              subtitle: 'Saat batas ambil (7 hari) mendekat',
              value: _notifPengingatAmbil,
              onChanged: (val) => setState(() => _notifPengingatAmbil = val),
            ),
            _switchTile(
              title: 'Promo & ajakan kembali',
              subtitle: 'Dari outlet langganan Anda',
              value: _notifPromo,
              onChanged: (val) => setState(() => _notifPromo = val),
            ),

            const SizedBox(height: 12),
            const SectionHeader(title: 'PRIVASI DATA'),
            _tile(context, Icons.policy_outlined, 'Kebijakan privasi & persetujuan', () {
              _showPrivacyPolicyDialog(context);
            }),
            _tile(
              context,
              Icons.no_accounts_outlined,
              'Hapus akun & anonimkan data',
              () => _showDeleteAccountDialog(context),
              textColor: AppColors.danger,
              iconColor: AppColors.danger,
            ),
          ],

          // 4. MENU ROLE PEGAWAI / KASIR (LENGKAP OPERASIONAL & SOP)
          if (user.isStaff) ...[
            const SectionHeader(title: 'AKUN & PROFIL KASIR'),
            _tile(context, Icons.person_outline_rounded, 'Ubah data profil', () {
              _showEditProfileDialog(context, user);
            }),
            _tile(context, Icons.lock_outline_rounded, 'Ubah kata sandi', () {
              _showChangePasswordDialog(context);
            }),

            const SizedBox(height: 12),
            const SectionHeader(title: 'INFORMASI OPERASIONAL'),
            _tile(context, Icons.storefront_outlined, 'Informasi Cabang & Shift', () {
              _showOutletInfoDialog(context);
            }),
            _tile(context, Icons.menu_book_rounded, 'Panduan Kasir & SOP Pengerjaan', () {
              _showCashierSopDialog(context);
            }),

            const SizedBox(height: 12),
            const SectionHeader(title: 'NOTIFIKASI TUGAS'),
            _switchTile(
              title: 'Notifikasi order & transisi',
              subtitle:
                  'Pemberitahuan saat ada order baru atau jadwal pengerjaan',
              value: _notifStaffTask,
              onChanged: (val) => setState(() => _notifStaffTask = val),
            ),
          ],

          // 5. TOMBOL KELUAR & VERSI APLIKASI
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text(
                'Keluar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'LaundryKu versi 1.0.0 (Semester 5)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Profile Header
  Widget _buildProfileHeader(UserModel user, String roleLabel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.phone.isNotEmpty ? user.phone : user.email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Tile Generator
  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? textColor,
    Color? iconColor,
  }) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Switch Tile
  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Ubah Profil
  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ubah Data Profil',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nomor telepon wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);
                            final ok = await ref
                                .read(authProvider.notifier)
                                .updateProfile(
                                  name: nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );
                            if (mounted) {
                              Navigator.pop(ctx);
                              showSnack(
                                context,
                                ok
                                    ? 'Profil berhasil diperbarui.'
                                    : 'Gagal memperbarui profil.',
                                isError: !ok,
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Alamat Tersimpan
  void _showSavedAddressDialog(BuildContext context, UserModel user) {
    final addrCtrl = TextEditingController(text: user.address ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                'Alamat Tersimpan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Alamat ini digunakan untuk mempermudah penjemputan dan pengantaran cucian Anda.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addrCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Jl. Melati No. 12, Kel. Sumerta, Denpasar',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setModalState(() => saving = true);
                          final ok = await ref
                              .read(authProvider.notifier)
                              .updateAddress(addrCtrl.text.trim());
                          if (mounted) {
                            Navigator.pop(ctx);
                            showSnack(
                              context,
                              ok
                                  ? 'Alamat tersimpan berhasil diperbarui.'
                                  : 'Gagal menyimpan alamat.',
                              isError: !ok,
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Alamat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Ubah Sandi
  void _showChangePasswordDialog(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ubah Kata Sandi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setModalState(() => obscure = !obscure),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: oldPassCtrl,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Saat Ini',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Kata sandi saat ini wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Baru (Min. 8 Karakter)',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.length < 8 ? 'Minimal 8 karakter' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Kata Sandi Baru',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Konfirmasi wajib diisi';
                    if (v != newPassCtrl.text) return 'Kata sandi tidak sama';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);
                            final ok = await ref
                                .read(authProvider.notifier)
                                .changePassword(
                                  currentPassword: oldPassCtrl.text,
                                  newPassword: newPassCtrl.text,
                                  confirmPassword: confirmPassCtrl.text,
                                );
                            if (mounted) {
                              Navigator.pop(ctx);
                              showSnack(
                                context,
                                ok
                                    ? 'Kata sandi berhasil diubah.'
                                    : (ref.read(authProvider).errorMessage ??
                                        'Gagal mengubah kata sandi.'),
                                isError: !ok,
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Kata Sandi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Kebijakan Privasi
  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Kebijakan Privasi & Perlindungan Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi (UU PDP)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(height: 24),
              _privacySection(
                '1. Pengumpulan Data Pribadi',
                'Kami mengumpulkan informasi identitas dasar (nama, surel, nomor telepon, dan alamat jemput/antar) semata-mata untuk kelancaran operasional laundry Anda.',
              ),
              _privacySection(
                '2. Penggunaan Data',
                'Data digunakan untuk pelacakan nota cucian, pengiriman notifikasi kesiapan pakaian, pemberian poin loyalitas member, dan rekonsiliasi pembayaran.',
              ),
              _privacySection(
                '3. Keamanan & Retensi',
                'Kata sandi Anda disimpan dengan enkripsi hash modern (bcrypt). Seluruh komunikasi data diamankan protokol TLS/HTTPS.',
              ),
              _privacySection(
                '4. Hak Anda Sebagai Subjek Data',
                'Anda memiliki hak untuk memperbarui profil, meminta penghapusan akun, atau anonimisasi data Anda kapan saja melalui aplikasi.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Saya Mengerti'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Hapus Akun
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            Text(
              'Hapus & Anonimkan?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Akun Anda akan dinonaktifkan dan data personal akan dianonimkan. Seluruh poin yang tersisa akan hangus dan Anda tidak dapat login kembali.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).deleteAccount();
              if (context.mounted) {
                showSnack(context, 'Akun Anda telah dinonaktifkan.');
              }
            },
            child: const Text('Ya, Hapus Akun'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: Info Cabang & Shift (Kasir)
  void _showOutletInfoDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'LaundryKu Cabang Utama',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Jl. Pendidikan No. 45, Denpasar, Bali · Telp: 081234567890',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 24),
            _infoRow('Status Shift', 'Aktif (Sedang Bertugas)', AppColors.success),
            _infoRow('Kode Cabang', 'LDRY-01', AppColors.textPrimary),
            _infoRow('Jam Operasional', '08.00 - 21.00 WITA', AppColors.textPrimary),
            _infoRow('Kebijakan Simpan', 'Maksimal 7 hari setelah Siap', AppColors.warning),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Dialog: SOP Kasir
  void _showCashierSopDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'SOP & Panduan Operasional Kasir',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const Divider(height: 20),
              _sopItem(
                '1. Penerimaan Order',
                'Pastikan memilih data pelanggan yang benar. Timbang pakaian kiloan (pembulatan 0,1 kg, minimum 1 kg).',
              ),
              _sopItem(
                '2. Gerbang Foto Kondisi Awal (Wajib)',
                'Sebelum memajukan status ke "Ditimbang", wajib memotret kondisi pakaian jika ada noda membandel atau sobekan sebagai bukti anti-klaim.',
              ),
              _sopItem(
                '3. State Machine Teratur',
                'Status harus dimajukan secara runtut: Diterima → Ditimbang → Dicuci → Disetrika → Siap → Diambil → Lunas.',
              ),
              _sopItem(
                '4. Batas Diskon',
                'Diskon lebih dari 10% subtotal wajib disetujui langsung oleh Pemilik.',
              ),
              _sopItem(
                '5. Rekonsiliasi Kas Shift',
                'Hitung uang fisik di laci kasir dan pastikan selisih kas harian berada di bawah 1%.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Saya Paham'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sopItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            desc,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Logout Confirm
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Anda harus memasukkan surel dan kata sandi kembali untuk masuk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
