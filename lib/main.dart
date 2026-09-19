import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const WalletApp());

class AppColors {
  static const bgTop = Color(0xFFDDE3F8);
  static const bgBottom = Color(0xFFE8EBFA);
  static const primary = Color(0xFF5B7BD5);
  static const ink = Color(0xFF2E3557);
  static const muted = Color(0xFF8A90AE);
  static const tile = Color(0xFF8E9BCB);
  static const panel = Color(0x408D9BCB);
  static const card = Color(0xFFD8DCF1);
  static const green = Color(0xFF8FC48F);
  static const red = Color(0xFFB9656A);
  static const amountRed = Color(0xFFD62F35);
  static const success = Color(0xFF3E8E5A);
}

const _sectionStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
);

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المحفظة',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary),
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

/// 5.00 -> 5 ، 5.50 -> 5.50
String fmtShort(double v) {
  final s = fmt(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
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
  final String name;
  final String currency;
  final double amount;
  final DateTime time;
  const _Transfer(this.name, this.currency, this.amount, this.time);
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

  final Map<String, double> _balances = {
    'EUR': 1312.40,
    'USD': 1428.67,
    'SYP': 18540000.00,
  };

  // بيانات تجريبية مأخوذة من التصميم — احذفها لتبدأ القائمة فارغة
  // (الأحدث أولاً)
  late final List<_Transfer> _transfers = [
    _Transfer('لولو محمد علي', 'USD', 5,
        DateTime.now().subtract(const Duration(days: 1))),
    _Transfer('لولو محمد علي', 'USD', 10,
        DateTime.now().subtract(const Duration(days: 2))),
    _Transfer('أبو خالد الحمصي.1', 'USD', 25,
        DateTime.now().subtract(const Duration(days: 3))),
  ];

  String _selected = 'USD';
  bool _hidden = false;
  int _tab = 0; // 0 الرئيسية، 1 التحويلات، 2 البطاقات، 3 الحساب

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
      _transfers.insert(
        0,
        _Transfer(r.name, currency, r.amount, DateTime.now()),
      );
    });

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
                      '$currency ${fmtShort(r.amount)} إلى ${r.name}',
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
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(bottom: false, child: _body()),
      ),
      floatingActionButton: _QrButton(onTap: () {}),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar:
          _BottomBar(index: _tab, onChanged: (i) => setState(() => _tab = i)),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _homeBody();
      case 1:
        return _transfersBody();
      case 2:
        return const _Placeholder('البطاقات');
      default:
        return const _Placeholder('الحساب');
    }
  }

  // ── تبويب الرئيسية ──
  Widget _homeBody() {
    final recent = _transfers.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceRow(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 176,
            child: _buildActions(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Text('آخر التحويلات', style: _sectionStyle),
              const Spacer(),
              if (_transfers.length > 5)
                TextButton(
                  onPressed: () => setState(() => _tab = 1),
                  child: const Text('عرض الكل'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: 64,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: recent.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 56),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التحويلات',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _transfers.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 56),
                    itemCount: _transfers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _TransferTile(_transfers[i], showTime: true),
                  ),
          ),
        ],
      ),
    );
  }

  // الصف العلوي: الرصيد (يمين) + العملات + زر الإخفاء (يسار)
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
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
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
                onTap: () => setState(() => _selected = c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: c == _selected ? 28 : 15,
                      fontWeight:
                          c == _selected ? FontWeight.w800 : FontWeight.w500,
                      color: c == _selected ? AppColors.ink : AppColors.muted,
                    ),
                    child: Text(c),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Material(
          color: const Color(0xFFA9B3D6),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _hidden = !_hidden),
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
                  color: AppColors.red,
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
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: c == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      errorText: error,
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xCCFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.amountRed),
      focusedErrorBorder: border(AppColors.amountRed, 1.5),
    );
  }

  Widget _buttons(String primaryLabel, VoidCallback onPrimary) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const pad = EdgeInsets.symmetric(vertical: 14);
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
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
              foregroundColor: AppColors.ink,
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
      backgroundColor: AppColors.bgBottom,
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
                Expanded(child: _Tile('مدفوعات', Icons.layers_rounded, () {})),
                const SizedBox(width: 10),
                Expanded(
                    child: _Tile('فواتير', Icons.receipt_long_rounded, () {})),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _Tile('حوالات', Icons.sync_alt_rounded, () {})),
                const SizedBox(width: 10),
                Expanded(
                    child: _Tile('بنوك', Icons.account_balance_rounded, () {})),
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
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
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
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  final _Transfer t;
  final bool showTime;
  const _TransferTile(this.t, {this.showTime = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: showTime ? 16 : 22,
          ),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (showTime) ...[
                      const SizedBox(height: 4),
                      Text(
                        fmtTime(t.time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${t.currency} ${fmtShort(t.amount)}',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: 60),
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
      elevation: 4,
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

  // بترتيب RTL: الرئيسية أقصى اليمين ثم التحويلات ثم البطاقات ثم الحساب
  static const _icons = [
    Icons.home_rounded,
    Icons.paid_outlined,
    Icons.credit_card_rounded,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['الرئيسية', 'التحويلات', 'البطاقات', 'الحساب'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < _icons.length; i++)
              IconButton(
                tooltip: _labels[i],
                onPressed: () => onChanged(i),
                iconSize: 30,
                icon: Icon(
                  _icons[i],
                  color: i == index ? AppColors.primary : AppColors.ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
