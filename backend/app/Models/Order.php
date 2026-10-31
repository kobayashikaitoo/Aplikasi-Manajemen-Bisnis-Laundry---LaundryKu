<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
class Order extends Model {
    protected $fillable = [
        'branch_id', 'customer_id', 'created_by_user_id', 'order_no', 'barcode',
        'status', 'subtotal', 'discount_amount', 'total_amount', 'holding_period_days',
        'due_at', 'completed_at', 'pickup_at', 'notes'
    ];
    protected $casts = [
        'subtotal' => 'integer', 'discount_amount' => 'integer', 'total_amount' => 'integer',
        'due_at' => 'datetime', 'completed_at' => 'datetime', 'pickup_at' => 'datetime'
    ];
    public function branch(): BelongsTo { return $this->belongsTo(Branch::class); }
    public function customer(): BelongsTo { return $this->belongsTo(Customer::class); }
    public function createdBy(): BelongsTo { return $this->belongsTo(User::class, 'created_by_user_id'); }
    public function items(): HasMany { return $this->hasMany(OrderItem::class); }
    public function statusLogs(): HasMany { return $this->hasMany(OrderStatusLog::class); }
    public function photos(): HasMany { return $this->hasMany(OrderPhoto::class); }
    public function payments(): HasMany { return $this->hasMany(Payment::class); }
    public function claims(): HasMany { return $this->hasMany(Claim::class); }
}
