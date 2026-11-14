def total(items):
    """items は (単価, 数量) の組のリスト。合計金額を返す。"""
    return sum(price * qty for price, qty in items)
