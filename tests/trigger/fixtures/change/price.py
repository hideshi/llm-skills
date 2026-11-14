def total(items):
    """items は (単価, 数量) の組のリスト。合計金額を返す。"""
    items = list(items)
    if any(qty < 0 for _, qty in items):
        raise ValueError("数量が負の組があります")
    amount = sum(price * qty for price, qty in items)
    if amount >= 10000:
        return amount * 9 // 10
    return amount
