<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    protected ReportService $reportService;

    public function __construct(ReportService $reportService)
    {
        $this->reportService = $reportService;
    }

    public function dashboard(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $summary = $this->reportService->getDashboardSummary($branchId);

        return response()->json([
            'data' => $summary
        ]);
    }

    public function cashflow(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $report = $this->reportService->getCashflow(
            $branchId,
            $request->get('start_date'),
            $request->get('end_date')
        );

        return response()->json([
            'data' => $report
        ]);
    }

    public function demoQueries(Request $request): JsonResponse
    {
        $branchId = $request->user()->branch_id ?? 1;
        $queries = $this->reportService->getDemoQueries($branchId);

        return response()->json([
            'data' => $queries
        ]);
    }

    public function exportCsv(Request $request)
    {
        $branchId = $request->user()->branch_id ?? 1;
        $report = $this->reportService->getCashflow(
            $branchId,
            $request->get('start_date'),
            $request->get('end_date')
        );

        $filename = "laporan_cashflow_laundryku_" . date('Ymd_His') . ".csv";

        $output = "\xEF\xBB\xBF"; // UTF-8 BOM for Excel compatibility
        $output .= "LAPORAN ARUS KAS (CASHFLOW) - LAUNDRYKU\n";
        $output .= "Tanggal Cetak: " . date('d/m/Y H:i:s') . " WITA\n";
        $output .= "Total Kas Masuk,Rp " . number_format($report['summary']['total_in'], 0, ',', '.') . "\n";
        $output .= "Total Kas Keluar,Rp " . number_format($report['summary']['total_out'], 0, ',', '.') . "\n";
        $output .= "Saldo Bersih (Net),Rp " . number_format($report['summary']['net'], 0, ',', '.') . "\n\n";

        $output .= "No,Tanggal (WITA),ID Trx,Tipe,Kategori,Deskripsi,Jumlah (Rp)\n";
        $i = 1;
        foreach ($report['transactions'] as $t) {
            $date = Carbon::parse($t->created_at)->setTimezone('Asia/Makassar')->format('d/m/Y H:i');
            $type = $t->transaction_type === 'in' ? 'KAS MASUK' : 'KAS KELUAR';
            $category = strtoupper($t->category ?? '-');
            $desc = '"' . str_replace('"', '""', $t->description ?? '-') . '"';
            $amount = $t->amount;
            $output .= "{$i},{$date},#{$t->id},{$type},{$category},{$desc},{$amount}\n";
            $i++;
        }

        return response($output, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ]);
    }

    public function exportPdf(Request $request)
    {
        $branchId = $request->user()->branch_id ?? 1;
        $report = $this->reportService->getCashflow(
            $branchId,
            $request->get('start_date'),
            $request->get('end_date')
        );

        $todayWita = Carbon::now('Asia/Makassar')->format('d F Y, H:i');
        $totalInFormatted = "Rp " . number_format($report['summary']['total_in'], 0, ',', '.');
        $totalOutFormatted = "Rp " . number_format($report['summary']['total_out'], 0, ',', '.');
        $netFormatted = "Rp " . number_format($report['summary']['net'], 0, ',', '.');

        $rowsHtml = "";
        $no = 1;
        foreach ($report['transactions'] as $t) {
            $date = Carbon::parse($t->created_at)->setTimezone('Asia/Makassar')->format('d/m/Y H:i');
            $typeLabel = $t->transaction_type === 'in' ? '<span style="color:#15803d;font-weight:bold;">+ MASUK</span>' : '<span style="color:#b91c1c;font-weight:bold;">- KELUAR</span>';
            $amountFormatted = "Rp " . number_format($t->amount, 0, ',', '.');
            $desc = htmlspecialchars($t->description ?? $t->category);
            $rowsHtml .= "<tr>
                <td style='text-align:center;'>{$no}</td>
                <td>{$date}</td>
                <td>{$desc}</td>
                <td style='text-align:center;'>{$typeLabel}</td>
                <td style='text-align:right;font-weight:bold;'>{$amountFormatted}</td>
            </tr>";
            $no++;
        }

        $html = "<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Laporan Keuangan LaundryKu</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; color: #1e293b; background: white; }
        .header { border-bottom: 2px solid #0b4d58; padding-bottom: 15px; margin-bottom: 25px; display: flex; justify-content: space-between; align-items: flex-start; }
        .title { font-size: 24px; font-weight: 800; color: #0b4d58; margin: 0; }
        .subtitle { font-size: 13px; color: #64748b; margin-top: 4px; }
        .summary-cards { display: flex; gap: 15px; margin-bottom: 30px; }
        .card { flex: 1; border: 1px solid #e2e8f0; border-radius: 10px; padding: 15px; background: #faf9f5; }
        .card-label { font-size: 12px; color: #64748b; font-weight: 600; text-transform: uppercase; }
        .card-value { font-size: 20px; font-weight: 800; margin-top: 6px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 13px; }
        th { background: #0b4d58; color: white; padding: 10px; text-align: left; }
        td { padding: 9px 10px; border-bottom: 1px solid #e2e8f0; }
        tr:nth-child(even) { background: #f8fafc; }
        .footer { margin-top: 50px; display: flex; justify-content: space-between; font-size: 13px; }
        .signature { text-align: center; width: 200px; border-top: 1px solid #333; padding-top: 8px; margin-top: 60px; }
        @media print {
            body { margin: 20px; }
            .no-print { display: none; }
        }
    </style>
</head>
<body>
    <div class='no-print' style='margin-bottom: 20px; text-align: right;'>
        <button onclick='window.print()' style='background:#0b4d58; color:white; border:none; padding:10px 20px; border-radius:8px; cursor:pointer; font-weight:bold;'>🖨️ Cetak / Simpan sebagai PDF</button>
    </div>
    <div class='header'>
        <div>
            <h1 class='title'>LAUNDRYKU</h1>
            <div class='subtitle'>Laporan Arus Kas Resmi & Rekonsiliasi Keuangan</div>
            <div class='subtitle'>Tanggal Cetak: {$todayWita} WITA</div>
        </div>
        <div style='text-align:right;'>
            <div style='font-size:14px; font-weight:700;'>Cabang Utama</div>
            <div class='subtitle'>Sistem Manajemen Operasional LaundryKu</div>
        </div>
    </div>
    <div class='summary-cards'>
        <div class='card'>
            <div class='card-label'>Total Kas Masuk</div>
            <div class='card-value' style='color:#15803d;'>{$totalInFormatted}</div>
        </div>
        <div class='card'>
            <div class='card-label'>Total Kas Keluar</div>
            <div class='card-value' style='color:#b91c1c;'>{$totalOutFormatted}</div>
        </div>
        <div class='card'>
            <div class='card-label'>Saldo Bersih (Net)</div>
            <div class='card-value' style='color:#0b4d58;'>{$netFormatted}</div>
        </div>
    </div>
    <h3 style='margin-bottom:8px; color:#0b4d58;'>Rincian Mutasi Transaksi Kas</h3>
    <table>
        <thead>
            <tr>
                <th style='width:40px; text-align:center;'>No</th>
                <th style='width:140px;'>Waktu (WITA)</th>
                <th>Keterangan / Deskripsi Transaksi</th>
                <th style='width:100px; text-align:center;'>Tipe</th>
                <th style='width:140px; text-align:right;'>Nominal</th>
            </tr>
        </thead>
        <tbody>
            {$rowsHtml}
        </tbody>
    </table>
    <div class='footer'>
        <div>
            <div>Dicetak otomatis oleh Sistem LaundryKu</div>
            <div style='color:#64748b; font-size:11px;'>Dokumen ini sah dan dapat digunakan sebagai arsip keuangan.</div>
        </div>
        <div>
            <div>Denpasar, " . date('d F Y') . "</div>
            <div class='signature'>Tanda Tangan Pemilik</div>
        </div>
    </div>
</body>
</html>";

        return response($html, 200, [
            'Content-Type' => 'text/html; charset=UTF-8',
        ]);
    }
}
