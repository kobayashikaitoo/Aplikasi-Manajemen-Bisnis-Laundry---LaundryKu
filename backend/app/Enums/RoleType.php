<?php

namespace App\Enums;

enum RoleType: string
{
    case Pemilik = 'pemilik';
    case Pegawai = 'pegawai';
    case Pelanggan = 'pelanggan';
    case Kurir = 'kurir';
}
