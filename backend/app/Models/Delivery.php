<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class Delivery extends Model {
    protected $fillable = ['order_id', 'courier_user_id', 'type', 'status', 'scheduled_at', 'completed_at', 'fee'];
    protected $casts = ['fee' => 'integer', 'scheduled_at' => 'datetime', 'completed_at' => 'datetime'];
    public function order(): BelongsTo { return $this->belongsTo(Order::class); }
    public function courier(): BelongsTo { return $this->belongsTo(User::class, 'courier_user_id'); }
}
