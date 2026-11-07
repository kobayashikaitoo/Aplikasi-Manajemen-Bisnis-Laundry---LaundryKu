<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;
class User extends Authenticatable {
    use HasFactory, Notifiable;
    protected $fillable = ['role_id', 'branch_id', 'name', 'phone', 'email', 'password', 'is_active'];
    protected $hidden = ['password'];
    protected $casts = ['password' => 'hashed', 'is_active' => 'boolean'];
    public function role(): BelongsTo { return $this->belongsTo(Role::class); }
    public function branch(): BelongsTo { return $this->belongsTo(Branch::class); }
    public function customer(): HasOne { return $this->hasOne(Customer::class); }
    public function notifications(): HasMany { return $this->hasMany(Notification::class); }
    public function isOwner(): bool { return $this->role?->name === 'pemilik'; }
    public function isStaff(): bool { return $this->role?->name === 'pegawai'; }
    public function isCustomer(): bool { return $this->role?->name === 'pelanggan'; }
    public function isCourier(): bool { return $this->role?->name === 'kurir'; }
}
