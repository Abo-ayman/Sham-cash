import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1F3B86),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const WalletApp());
}

// ───────────────────────── الألوان ─────────────────────────

class AppColors {
  static const bgTop = Color(0xFF0E1A47);
  static const bgBottom = Color(0xFF1F3B86);
  static const primary = Color(0xFF4C8BFF);
  static const text = Colors.white;
  static const muted = Color(0xFFB4C0E6);
  static const tile = Color(0x664F6BC8);
  static const panel = Color(0x2EFFFFFF);
  static const card = Color(0x40FFFFFF);
  static const green = Color(0xFF3E8C87);
  static const purple = Color(0xFF71457F);
  static const amountRed = Color(0xFFFF4B4B);
  static const success = Color(0xFF2E9E6A);
  static const bar = Color(0xFF1C3070);
  static const dialog = Color(0xFF1B2E6B);
}

const _sectionStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w700,
  color: AppColors.text,
);

// الرصيد الأصلي لكل عملة (يرجع إليه رصيد USD تلقائياً عند الانخفاض)
const Map<String, double> _initialBalances = {
  'EUR': 1312.40,
  'USD': 1428.67,
  'SYP': 18540000.00,
};

// عندما يصل رصيد الدولار إلى هذا الحد أو أقل يرجع للرصيد الأصلي
const double _lowUsdThreshold = 10;

const String _prefsKey = 'wallet_state_v1';

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المحفظة',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.primary,
        // الخط مضمَّن بوزن 700 فقط، فيظهر كل النص بولد
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: AppColors.bgTop,
      ),
      // اتجاه RTL بدون الحاجة لأي حزمة إضافية
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    );
  }
}

// ───────────────────────── أدوات مساعدة ─────────────────────────

/// 1428.67 -> 1,428.67
String fmt(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '$intPart.${parts[1]}';
}

/// 5.00 -> 5 ، 0.50 -> 0.5 ، 1950.00 -> 1,950
String fmtAmount(double v) {
  final s = fmt(v);
  if (s.endsWith('.00')) return s.substring(0, s.length - 3);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}

/// $0.5 ، €10 ، 100 ل.س
String moneyLabel(String currency, double v) {
  final a = fmtAmount(v);
  switch (currency) {
    case 'USD':
      return '\$$a';
    case 'EUR':
      return '€$a';
    default:
      return '$a ل.س';
  }
}

/// 2026/09/12 - 20:14:03
String fmtDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} - '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// يقبل الأرقام العربية والإنجليزية
double? parseAmount(String input) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    final i = arabicDigits.indexOf(ch);
    if (i >= 0) {
      buf.write(i);
    } else if (ch == '٫') {
      buf.write('.');
    } else {
      buf.write(ch);
    }
  }
  final v = double.tryParse(buf.toString());
  if (v == null) return null;
  return (v * 100).round() / 100;
}

class _Transfer {
  final String id; // رقم عملية وهمي مثل #447337927
  final String name;
  final String currency;
  final double amount;
  final DateTime time;

  const _Transfer({
    required this.id,
    required this.name,
    required this.currency,
    required this.amount,
    required this.time,
  });

  factory _Transfer.fromJson(Map<String, dynamic> j) => _Transfer(
        id: j['id'] as String,
        name: j['name'] as String,
        currency: j['currency'] as String,
        amount: (j['amount'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'amount': amount,
        'time': time.millisecondsSinceEpoch,
      };
}

class _SendResult {
  final String name;
  final double amount;
  const _SendResult(this.name, this.amount);
}

// ───────────────────────── الشاشة الرئيسية ─────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const currencies = ['EUR', 'USD', 'SYP'];

  final Map<String, double> _balances = Map.of(_initialBalances);
  final List<_Transfer> _transfers = [];
  final Random _rng = Random();

  String _selected = 'USD';
  bool _hidden = false;
  int _tab = 0; // 0 الرئيسية، 1 التحويلات، 2 الخدمات، 3 حسابي
  int _unread = 0; // عدد التحويلات الجديدة (شارة الجرس)
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── الحفظ والاسترجاع ──

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final bal = (m['balances'] as Map<String, dynamic>?) ?? {};
        for (final c in _initialBalances.keys) {
          final v = bal[c];
          if (v is num) _balances[c] = v.toDouble();
        }
        final sel = m['selected'];
        if (sel is String && _initialBalances.containsKey(sel)) {
          _selected = sel;
        }
        _hidden = m['hidden'] == true;
        final un = m['unread'];
        if (un is int) _unread = un;
        final list = m['transfers'];
        if (list is List) {
          _transfers
            ..clear()
            ..addAll(list.map((e) => _Transfer.fromJson(e as Map<String, dynamic>)));
        }
      }
    } catch (_) {
      // بيانات تالفة: نبدأ من القيم الافتراضية
    }
    _applyAutoRefill();
    if (!mounted) return;
    setState(() => _loaded = true);
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'balances': _balances,
          'selected': _selected,
          'hidden': _hidden,
          'unread': _unread,
          'transfers': _transfers.map((t) => t.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  // إذا وصل رصيد الدولار إلى 10 أو أقل يرجع تلقائياً للرصيد الأصلي
  void _applyAutoRefill() {
    if ((_balances['USD'] ?? 0) <= _lowUsdThreshold) {
      _balances['USD'] = _initialBalances['USD']!;
    }
  }

  // رقم عملية وهمي: #44 + 7 أرقام
  String _newId() {
    String id;
    do {
      id = '#44${1000000 + _rng.nextInt(9000000)}';
    } while (_transfers.any((t) => t.id == id));
    return id;
  }

  void _goTo(int i) {
    setState(() {
      _tab = i;
      if (i == 1) _unread = 0;
    });
    _save();
  }

  // ── فتح نافذة الإرسال ──
  Future<void> _openSend() async {
    final currency = _selected;
    final result = await showDialog<_SendResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SendDialog(
        currency: currency,
        balance: _balances[currency]!,
      ),
    );
    if (result != null && mounted) _addTransfer(result, currency);
  }

  void _addTransfer(_SendResult r, String currency) {
    setState(() {
      final newBalance = _balances[currency]! - r.amount;
      _balances[currency] = (newBalance * 100).round() / 100;
      _applyAutoRefill();
      _transfers.insert(
        0,
        _Transfer(
          id: _newId(),
          name: r.name,
          currency: currency,
          amount: r.amount,
          time: DateTime.now(),
        ),
      );
      _unread++;
    });
    _save();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تم التحويل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${moneyLabel(currency, r.amount)} إلى ${r.name}',
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.bgTop,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: CustomPaint(
          painter: _HexPainter(),
          child: SafeArea(bottom: false, child: _body()),
        ),
      ),
      floatingActionButton: _QrButton(onTap: () {}),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(index: _tab, onChanged: _goTo),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _homeBody();
      case 1:
        return _transfersBody();
      case 2:
        return const _Placeholder('الخدمات');
      default:
        return const _Placeholder('حسابي');
    }
  }

  // ── الشريط العلوي: الشعار (يمين) + الجرس (يسار) ──
  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x33FFFFFF),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Color(0xFF6FE3C1), size: 26),
        ),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _goTo(1),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 32),
                if (_unread > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unread',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── تبويب الرئيسية ──
  Widget _homeBody() {
    final recent = _transfers.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          const SizedBox(height: 18),
          _buildBalanceRow(),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 176,
            child: _buildActions(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text('آخر التحويلات', style: _sectionStyle),
              const Spacer(),
              if (_transfers.length > 5)
                TextButton(
                  onPressed: () => _goTo(1),
                  child: const Text('عرض الكل',
                      style: TextStyle(color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 100,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF7FA8FF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: recent.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 130),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _TransferTile(recent[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── تبويب التحويلات ──
  Widget _transfersBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          const SizedBox(height: 22),
          const Text('آخر التحويلات', style: _sectionStyle),
          const SizedBox(height: 14),
          Expanded(
            child: _transfers.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 130),
                    itemCount: _transfers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _TransferCard(_transfers[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // الرصيد (يمين) + العملات + زر الإخفاء (يسار)
  Widget _buildBalanceRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _hidden ? '••••••' : fmt(_balances[_selected]!),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in currencies)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _selected = c);
                  _save();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: c == _selected ? 30 : 16,
                      fontWeight: FontWeight.w700,
                      color: c == _selected ? AppColors.text : AppColors.muted,
                    ),
                    child: Text(c),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Material(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _hidden = !_hidden);
              _save();
            },
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                _hidden
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // لوحة الأزرار السريعة (يمين) + زرّا استقبال/إرسال (يسار)
  Widget _buildActions() {
    return Row(
      children: [
        const Expanded(flex: 31, child: _QuickPanel()),
        const SizedBox(width: 14),
        Expanded(
          flex: 29,
          child: Column(
            children: [
              Expanded(
                child: _BigButton(
                  label: 'استقبال',
                  icon: Icons.call_received_rounded,
                  color: AppColors.green,
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _BigButton(
                  label: 'إرسال',
                  icon: Icons.call_made_rounded,
                  color: AppColors.purple,
                  onTap: _openSend,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── نافذة الإرسال (خطوتان) ─────────────────────────

class _SendDialog extends StatefulWidget {
  final String currency;
  final double balance;
  const _SendDialog({required this.currency, required this.balance});

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  int _step = 0; // 0 اسم المستقبل، 1 المبلغ
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم المستقبل');
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  void _send() {
    final amount = parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    if (amount > widget.balance) {
      setState(() => _error = 'الرصيد غير كافٍ');
      return;
    }
    Navigator.pop(context, _SendResult(_nameCtrl.text.trim(), amount));
  }

  InputDecoration _dec(String hint, {String? error, String? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    const clear = Color(0x00000000);
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      errorText: error,
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
      filled: true,
      fillColor: const Color(0x26FFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(clear, 0),
      enabledBorder: border(clear, 0),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.amountRed, 1),
      focusedErrorBorder: border(AppColors.amountRed),
    );
  }

  Widget _buttons(String primaryLabel, VoidCallback onPrimary) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const pad = EdgeInsets.symmetric(vertical: 14);
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: pad,
              shape: shape,
            ),
            child: Text(primaryLabel, style: textStyle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: pad,
              shape: shape,
            ),
            child: const Text('إلغاء', style: textStyle),
          ),
        ),
      ],
    );
  }

  Widget _nameStep() {
    return SizedBox(
      key: const ValueKey('name-step'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اسم المستقبل', style: _sectionStyle),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            cursorColor: Colors.white,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _next(),
            decoration: _dec('أدخل اسم المستقبل', error: _error),
          ),
          const SizedBox(height: 20),
          _buttons('التالي', _next),
        ],
      ),
    );
  }

  Widget _amountStep() {
    return SizedBox(
      key: const ValueKey('amount-step'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المبلغ', style: _sectionStyle),
          const SizedBox(height: 4),
          Text(
            'إلى: ${_nameCtrl.text.trim()}',
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            cursorColor: Colors.white,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
            decoration: _dec('0.00', error: _error, suffix: widget.currency),
          ),
          const SizedBox(height: 20),
          _buttons('إرسال', _send),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _step == 0 ? _nameStep() : _amountStep(),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── ويدجتات الواجهة ─────────────────────────

/// أشكال سداسية باهتة في الخلفية
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0DFFFFFF);

    void hex(Offset c, double r) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = pi / 3 * i + pi / 6;
        final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    hex(Offset(size.width * 0.72, size.height * 0.20), 190);
    hex(Offset(size.width * 0.10, size.height * 0.42), 150);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickPanel extends StatelessWidget {
  const _QuickPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _Tile('خدماتي', Icons.bookmark_rounded, () {})),
                const SizedBox(width: 10),
                Expanded(child: _Tile('مدفوعات', Icons.layers_rounded, () {})),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: _Tile('فواتير', Icons.receipt_long_rounded, () {})),
                const SizedBox(width: 10),
                Expanded(child: _FolderTile(onTap: () {})),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Tile(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tile,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// مربع "مجلد" فيه أربع خانات صغيرة
class _FolderTile extends StatelessWidget {
  final VoidCallback onTap;
  const _FolderTile({required this.onTap});

  Widget _mini(IconData? icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: icon == null ? null : Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tile,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Row(children: [
                  _mini(Icons.account_balance_rounded),
                  _mini(Icons.layers_rounded),
                ]),
              ),
              Expanded(
                child: Row(children: [_mini(null), _mini(null)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة التحويل في الشاشة الرئيسية (ملخص)
class _TransferTile extends StatelessWidget {
  final _Transfer t;
  const _TransferTile(this.t);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${t.currency} ${fmtAmount(t.amount)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amountRed,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.file_upload_rounded,
                  color: AppColors.amountRed, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة التحويل في تبويب التحويلات (الاسم + المبلغ | رقم العملية + التاريخ)
class _TransferCard extends StatelessWidget {
  final _Transfer t;
  const _TransferCard(this.t);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '— ${moneyLabel(t.currency, t.amount)}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amountRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  t.id,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fmtDateTime(t.time),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: 100),
        child: Text(
          'لا توجد تحويلات بعد',
          style: TextStyle(fontSize: 16, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title — قريباً',
        style: const TextStyle(fontSize: 18, color: AppColors.muted),
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QrButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: const SizedBox(
          width: 76,
          height: 76,
          child: Icon(Icons.qr_code_scanner_rounded,
              color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

  // بترتيب RTL: الرئيسية أقصى اليمين ثم التحويلات ثم الخدمات ثم حسابي
  static const _icons = [
    Icons.home_rounded,
    Icons.paid_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['الرئيسية', 'التحويلات', 'الخدمات', 'حسابي'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: AppColors.bar,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                for (int i = 0; i < _icons.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onChanged(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icons[i],
                            size: 28,
                            color:
                                i == index ? AppColors.primary : Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  i == index ? AppColors.primary : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
