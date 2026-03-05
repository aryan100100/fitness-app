// [HEALTH APP] — Portion Reference Lookup
// Visual serving size hints for the 50 most commonly logged foods.
// Only shown when a match exists — never shows wrong info.

class PortionReferences {
  PortionReferences._();

  static const Map<String, String> _refs = {
    // Grains & Staples
    'rice':                '1 cup cooked ≈ your fist (≈180g)',
    'rice (cooked)':       '1 cup cooked ≈ your fist (≈180g)',
    'white rice':          '1 cup cooked ≈ your fist (≈180g)',
    'brown rice':          '1 cup cooked ≈ your fist (≈180g)',
    'roti':                '1 roti ≈ a tea saucer (≈35g)',
    'chapati':             '1 roti ≈ a tea saucer (≈35g)',
    'paratha':             '1 paratha ≈ a small plate (≈80g)',
    'bread (white)':       '1 slice ≈ a playing card (≈30g)',
    'bread (brown)':       '1 slice ≈ a playing card (≈30g)',
    'pasta (cooked)':      '1 cup cooked ≈ your fist (≈200g)',
    'oats (rolled)':       '½ cup dry ≈ a cupped palm (≈40g)',
    'idli':                '2 medium idlis ≈ 2 golf balls (≈80g)',
    'dosa':                '1 dosa ≈ a standard dinner plate (≈75g)',
    'poha':                '1 cup cooked ≈ your fist (≈100g)',
    'upma':                '1 cup cooked ≈ your fist (≈120g)',

    // Proteins
    'chicken breast':      '100g ≈ a deck of cards',
    'chicken breast (cooked)': '100g ≈ a deck of cards',
    'egg (boiled)':        '1 large egg ≈ a closed fist (≈60g)',
    'egg boiled':          '1 large egg ≈ a closed fist (≈60g)',
    'egg (scrambled)':     '2 eggs ≈ the size of your open hand',
    'paneer':              '100g ≈ a small matchbox',
    'fish fillet':         '100g ≈ a deck of cards',
    'salmon':              '100g ≈ a deck of cards',
    'tuna (canned)':       '½ can ≈ a cupped palm (≈85g)',
    'beef (lean)':         '100g ≈ a deck of cards',
    'greek yoghurt':       '1 cup ≈ a tennis ball (≈245g)',
    'curd / yoghurt':      '1 cup ≈ a tennis ball (≈200g)',

    // Pulses & Legumes
    'dal (cooked)':        '1 cup cooked ≈ a cupped handful (≈200g)',
    'rajma (cooked)':      '1 cup cooked ≈ your fist (≈180g)',
    'chole (cooked)':      '1 cup cooked ≈ your fist (≈180g)',
    'lentils (cooked)':    '1 cup cooked ≈ your fist (≈200g)',

    // Dairy
    'milk (full fat)':     '1 glass ≈ a closed fist (≈240ml)',
    'milk (skimmed)':      '1 glass ≈ a closed fist (≈240ml)',
    'cheddar cheese':      '30g ≈ 2 stacked dice',
    'butter':              '1 tbsp ≈ your thumb tip (≈14g)',
    'ghee':                '1 tsp ≈ your fingernail (≈5g)',
    'cream cheese':        '2 tbsp ≈ your thumb (≈30g)',

    // Fats & Oils
    'oil (any)':           '1 tbsp ≈ your thumb tip (≈15ml)',
    'olive oil':           '1 tbsp ≈ your thumb tip (≈15ml)',
    'peanut butter':       '2 tbsp ≈ a ping-pong ball (≈32g)',
    'almond butter':       '2 tbsp ≈ a ping-pong ball (≈32g)',
    'cashews':             '28g ≈ a small handful',
    'almonds':             '28g ≈ a small handful (≈23 nuts)',
    'walnuts':             '28g ≈ a small handful (≈14 halves)',
    'peanuts':             '28g ≈ a small handful',

    // Fruits & Vegetables
    'banana':              '1 medium banana ≈ the length of your hand (≈120g)',
    'apple':               '1 medium apple ≈ a tennis ball (≈180g)',
    'orange':              '1 medium orange ≈ a tennis ball (≈130g)',
    'potato (boiled)':     '1 medium potato ≈ your fist (≈150g)',
    'sweet potato':        '1 medium ≈ your fist (≈130g)',
    'broccoli':            '1 cup florets ≈ your closed fist (≈90g)',

    // Snacks
    'samosa':              '1 samosa ≈ 2 golf balls (≈60g)',
    'biscuit (marie)':     '1 biscuit ≈ 1 poker chip (≈8g)',
    'dark chocolate':      '2 squares ≈ 2 dice (≈20g)',
  };

  /// Returns a portion hint for the given food name, or null if not found.
  static String? get(String foodName) {
    final key = foodName.toLowerCase().trim();
    // Direct match
    if (_refs.containsKey(key)) return _refs[key];
    // Partial match — check if any key is contained in the food name
    for (final entry in _refs.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }
}
