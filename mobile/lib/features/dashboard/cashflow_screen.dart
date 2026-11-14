import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/data/models.dart';
import '../orders/orders_providers.dart';

/// A1 Cashflow — daily cash in/out plus owner expense recording (P-11).
class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashAsync = ref.watch(cashflowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashflow & Arus Kas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor Laporan (PDF & Excel/CSV)',
            onPressed: () {
              cashAsync.whenData((flow) => _showExportDialog(context, flow));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(context, ref),
        icon: const Icon(Icons.remove_circle_outline_rounded),
        label: const Text('Catat pengeluaran'),
        backgroundColor: AppColors.danger,
      ),
      body: cashAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(cashflowProvider),
        ),
        data: (flow) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                      child: StatTile(
                          label: 'Kas masuk',
                          value: Formatters.rupiah(flow.totalIn),
                          icon: Icons.arrow_downward_rounded,
                          color: AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: StatTile(
                          label: 'Kas keluar',
                          value: Formatters.rupiah(flow.totalOut),
                          icon: Icons.arrow_upward_rounded,
                          color: AppColors.danger)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: StatTile(
                          label: 'Saldo',
                          value: Formatters.rupiah(flow.net),
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.primary)),
                ],
              ),
            ),
            const SectionHeader(title: 'Transaksi terbaru'),
            Expanded(
              child: flow.transactions.isEmpty
                  ? const EmptyView(
                      icon: Icons.payments_rounded,
                      message: 'Belum ada transaksi kas pada periode ini.')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: flow.transactions.length,
                      itemBuilder: (context, i) {
                        final t = flow.transactions[i];
                        final isIn = t.transactionType == 'in';
                        return SectionCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isIn
                                    ? AppColors.successLight
                                    : AppColors.dangerLight,
                                child: Icon(
                                    isIn
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIn
                                        ? AppColors.success
                                        : AppColors.danger,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(t.description ?? t.category,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${t.category} · ${Formatters.dateTimeWita(t.createdAt)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Text(
                                  '${isIn ? '+' : '−'} ${Formatters.rupiah(t.amount)}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isIn
                                          ? AppColors.success
                                          : AppColors.danger)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseForm(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'operasional';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Catat Pengeluaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(
                      value: 'operasional', child: Text('Biaya operasional')),
                  DropdownMenuItem(
                      value: 'bahan', child: Text('Bahan (deterjen dll.)')),
                  DropdownMenuItem(
                      value: 'gaji', child: Text('Gaji pegawai')),
                  DropdownMenuItem(
                      value: 'sewa', child: Text('Sewa / listrik')),
                  DropdownMenuItem(
                      value: 'lainnya', child: Text('Lainnya')),
                ],
                onChanged: (v) => setSheet(() => category = v ?? 'operasional'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Jumlah (Rp)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Keterangan'),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan pengeluaran'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || descCtrl.text.trim().isEmpty) {
      showSnack(context, 'Jumlah dan keterangan wajib diisi dengan benar.',
          isError: true);
      return;
    }
    try {
      await ref.read(laundryRepositoryProvider).recordExpense(
            amount: amount,
            category: category,
            description: descCtrl.text.trim(),
          );
      ref.invalidate(cashflowProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        showSnack(context, 'Pengeluaran ${Formatters.rupiah(amount)} tercatat.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, isError: true);
    }
  }

  void _showExportDialog(BuildContext context, CashflowModel flow) {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(DateTime.now());

    // Generate CSV data
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('LAPORAN ARUS KAS (CASHFLOW) - LAUNDRYKU');
    csvBuffer.writeln('Tanggal Cetak: $nowStr WITA');
    csvBuffer.writeln('Total Kas Masuk,"${Formatters.rupiah(flow.totalIn)}"');
    csvBuffer.writeln('Total Kas Keluar,"${Formatters.rupiah(flow.totalOut)}"');
    csvBuffer.writeln('Saldo Bersih (Net),"${Formatters.rupiah(flow.net)}"');
    csvBuffer.writeln('');
    csvBuffer.writeln('No,Tanggal,Tipe,Kategori,Keterangan,Jumlah (Rp)');

    for (var i = 0; i < flow.transactions.length; i++) {
      final t = flow.transactions[i];
      final typeLabel = t.transactionType == 'in' ? 'KAS MASUK' : 'KAS KELUAR';
      final desc = '"${(t.description ?? t.category).replaceAll('"', '""')}"';
      csvBuffer.writeln('${i + 1},"${t.createdAt}",$typeLabel,${t.category},$desc,${t.amount}');
    }
    final csvString = csvBuffer.toString();

    // Generate PDF summary document string
    final pdfBuffer = StringBuffer();
    pdfBuffer.writeln('========================================================');
    pdfBuffer.writeln('                LAUNDRYKU - LAPORAN KEUANGAN            ');
    pdfBuffer.writeln('========================================================');
    pdfBuffer.writeln('Tanggal Cetak  : $nowStr WITA');
    pdfBuffer.writeln('Cabang         : Cabang Utama (Denpasar)');
    pdfBuffer.writeln('--------------------------------------------------------');
    pdfBuffer.writeln('RINGKASAN ARUS KAS:');
    pdfBuffer.writeln('  • Total Kas Masuk  : ${Formatters.rupiah(flow.totalIn)}');
    pdfBuffer.writeln('  • Total Kas Keluar : ${Formatters.rupiah(flow.totalOut)}');
    pdfBuffer.writeln('  • Saldo Bersih     : ${Formatters.rupiah(flow.net)}');
    pdfBuffer.writeln('--------------------------------------------------------');
    pdfBuffer.writeln('RINCIAN TRANSAKSI MUTASI (${flow.transactions.length} Transaksi):');
    for (var i = 0; i < flow.transactions.length; i++) {
      final t = flow.transactions[i];
      final symbol = t.transactionType == 'in' ? '(+) Masuk' : '(-) Keluar';
      pdfBuffer.writeln('${i + 1}. [${t.createdAt}] $symbol: ${Formatters.rupiah(t.amount)}');
      pdfBuffer.writeln('   Ket: ${t.description ?? t.category}');
    }
    pdfBuffer.writeln('--------------------------------------------------------');
    pdfBuffer.writeln('Dokumen ini sah dan dicetak oleh Sistem LaundryKu.');
    pdfBuffer.writeln('========================================================');
    final pdfDocString = pdfBuffer.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.download_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ekspor Laporan Keuangan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Pilih format file: Excel/CSV atau Dokumen PDF',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                labelColor: AppColors.primary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_rounded), text: 'Excel / CSV'),
                  Tab(icon: Icon(Icons.picture_as_pdf_rounded), text: 'PDF / Cetak'),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: TabBarView(
                  children: [
                    // Tab 1: CSV / Excel
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                csvString,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Salin Data CSV (Siap Buka di Excel)'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: csvString));
                            Navigator.pop(ctx);
                            showSnack(context, 'Data CSV berhasil disalin! Anda dapat menempelkannya di Excel atau Spreadsheet.');
                          },
                        ),
                      ],
                    ),
                    // Tab 2: PDF Document
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                pdfDocString,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('Salin Format Dokumen PDF'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: pdfDocString));
                            Navigator.pop(ctx);
                            showSnack(context, 'Format dokumen laporan keuangan berhasil disalin ke clipboard.');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
