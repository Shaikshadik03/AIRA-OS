import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/business/presentation/providers/business_provider.dart';

class BusinessScreen extends ConsumerStatefulWidget {
  const BusinessScreen({super.key});

  @override
  ConsumerState<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends ConsumerState<BusinessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Invoice form states
  final _invoiceNumController = TextEditingController(text: 'INV-1001');
  final _clientNameController = TextEditingController();
  final _clientCompanyController = TextEditingController();
  final _taxRateController = TextEditingController(text: '18');

  // Dynamic invoice items list
  final List<Map<String, dynamic>> _invoiceItems = [
    {'description': 'Software Development Services', 'price': 25000.0, 'qty': 1}
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(businessProvider.notifier).loadClients());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceNumController.dispose();
    _clientNameController.dispose();
    _clientCompanyController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Business CRM & Invoices', style: AiraTypography.h4),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AiraColors.electricCyan,
          labelColor: AiraColors.electricCyan,
          unselectedLabelColor: AiraColors.textMuted,
          tabs: const [
            Tab(text: 'Clients', icon: Icon(Icons.people_alt_outlined)),
            Tab(text: 'Invoice Generator', icon: Icon(Icons.receipt_long_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientsTab(state),
          _buildInvoiceTab(state),
        ],
      ),
    );
  }

  // ──────────────────── Clients Tab ────────────────────

  Widget _buildClientsTab(BusinessState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(businessProvider.notifier).loadClients(),
      color: AiraColors.electricCyan,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Client Directory', style: AiraTypography.h5),
              AiraButton(
                label: 'Add Client',
                icon: Icons.add,
                onPressed: () => _showAddClientDialog(),
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.clients.isEmpty)
            _buildEmptyState('No clients in directory. Add contacts above!', Icons.people_outline_rounded)
          else
            ...state.clients.map((client) => _buildClientCard(client)),
        ],
      ),
    );
  }

  Widget _buildClientCard(BusinessClient client) {
    Color statusColor;
    switch (client.status) {
      case 'active':
        statusColor = AiraColors.success;
        break;
      case 'inactive':
        statusColor = AiraColors.error;
        break;
      default:
        statusColor = AiraColors.warning;
    }

    return Dismissible(
      key: Key(client.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AiraColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AiraColors.error),
      ),
      onDismissed: (_) {
        ref.read(businessProvider.notifier).deleteClient(client.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GlassmorphicContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AiraColors.electricCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AiraColors.glassBorder),
                ),
                child: Center(
                  child: Text(
                    client.name[0].toUpperCase(),
                    style: AiraTypography.h5.copyWith(color: AiraColors.electricCyan, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: AiraTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    if (client.company != null && client.company!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(client.company!, style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted)),
                    ],
                    if (client.email != null && client.email!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(client.email!, style: AiraTypography.caption.copyWith(color: AiraColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  client.status.toUpperCase(),
                  style: AiraTypography.overline.copyWith(color: statusColor, fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String status = 'lead';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AiraColors.cardDark,
          title: Text('Add Client', style: AiraTypography.h5),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AiraTextField(controller: nameController, hintText: 'Client Name'),
                const SizedBox(height: 12),
                AiraTextField(controller: companyController, hintText: 'Company Name'),
                const SizedBox(height: 12),
                AiraTextField(controller: emailController, hintText: 'Email Address', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                AiraTextField(controller: phoneController, hintText: 'Phone Number', keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                // Status select
                Row(
                  children: [
                    Text('Status: ', style: AiraTypography.bodySmall),
                    const SizedBox(width: 8),
                    ...['lead', 'active'].map((s) => Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => status = s),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: status == s
                                    ? AiraColors.electricCyan.withValues(alpha: 0.15)
                                    : AiraColors.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status == s ? AiraColors.electricCyan : AiraColors.glassBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  s.toUpperCase(),
                                  style: AiraTypography.overline.copyWith(
                                    color: status == s ? AiraColors.electricCyan : AiraColors.textMuted,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AiraColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AiraColors.electricCyan),
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                ref.read(businessProvider.notifier).addClient({
                  'name': nameController.text.trim(),
                  'company': companyController.text.trim(),
                  'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                  'phone': phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                  'status': status,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Invoice Tab ────────────────────

  Widget _buildInvoiceTab(BusinessState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice Configuration', style: AiraTypography.h5),
          const SizedBox(height: 12),
          AiraTextField(controller: _invoiceNumController, hintText: 'Invoice Number'),
          const SizedBox(height: 8),
          AiraTextField(controller: _clientNameController, hintText: 'Client Name'),
          const SizedBox(height: 8),
          AiraTextField(controller: _clientCompanyController, hintText: 'Client Company (Optional)'),
          const SizedBox(height: 8),
          AiraTextField(controller: _taxRateController, hintText: 'Tax Rate (%)', keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          // Invoice Items Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Billing Items', style: AiraTypography.h5),
              AiraButton(
                label: 'Add Item',
                icon: Icons.add,
                onPressed: () {
                  setState(() {
                    _invoiceItems.add({'description': 'Consulting Hours', 'price': 5000.0, 'qty': 1});
                  });
                },
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Render dynamic items list
          ...List.generate(_invoiceItems.length, (index) => _buildInvoiceItemRow(index)),
          const SizedBox(height: 32),
          AiraButton(
            label: 'Generate Invoice',
            onPressed: () {
              if (_clientNameController.text.trim().isEmpty) return;
              ref.read(businessProvider.notifier).createInvoice({
                'client_name': _clientNameController.text.trim(),
                'client_company': _clientCompanyController.text.trim(),
                'invoice_number': _invoiceNumController.text.trim(),
                'tax_rate': double.tryParse(_taxRateController.text.trim()) ?? 0.0,
                'items': _invoiceItems,
              });
              _showInvoiceCompiledModal();
            },
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemRow(int index) {
    final item = _invoiceItems[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AiraColors.surfaceDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              style: AiraTypography.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Item Name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              controller: TextEditingController(text: item['description']),
              onChanged: (val) => _invoiceItems[index]['description'] = val,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              keyboardType: TextInputType.number,
              style: AiraTypography.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Unit Price',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              controller: TextEditingController(text: item['price'].toString()),
              onChanged: (val) {
                _invoiceItems[index]['price'] = double.tryParse(val) ?? 0.0;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              keyboardType: TextInputType.number,
              style: AiraTypography.bodySmall,
              decoration: const InputDecoration(
                hintText: 'Qty',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              controller: TextEditingController(text: item['qty'].toString()),
              onChanged: (val) {
                _invoiceItems[index]['qty'] = int.tryParse(val) ?? 1;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AiraColors.error),
            onPressed: () {
              setState(() {
                _invoiceItems.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  void _showInvoiceCompiledModal() {
    Future.microtask(() {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AiraColors.cardDark,
        builder: (ctx) {
          final bState = ref.watch(businessProvider);
          final invoice = bState.generatedInvoice;

          if (bState.isLoading) {
            return const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator(color: AiraColors.electricCyan)),
            );
          }

          if (invoice == null) {
            return const SizedBox(
              height: 250,
              child: Center(child: Text('Generating Invoice failed.')),
            );
          }

          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Invoice Successfully Compiled', style: AiraTypography.h5),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref.read(businessProvider.notifier).clearInvoice();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassmorphicContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _totalDetailRow('Subtotal', '₹${invoice.subtotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _totalDetailRow('Tax Deductions', '₹${invoice.tax.toStringAsFixed(2)}'),
                      const Divider(color: Colors.white10),
                      _totalDetailRow('Total Billed Amount', '₹${invoice.total.toStringAsFixed(2)}', isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Rendered HTML Document Output:', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AiraColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AiraColors.glassBorder),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        invoice.html,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AiraButton(
                        label: 'Copy HTML to Clipboard',
                        icon: Icons.copy_all,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invoice.html));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invoice HTML copied!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _totalDetailRow(String title, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: isTotal ? AiraTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold) : AiraTypography.bodyMedium),
        Text(
          value,
          style: isTotal
              ? AiraTypography.bodyLarge.copyWith(color: AiraColors.success, fontWeight: FontWeight.bold)
              : AiraTypography.bodyMedium,
        ),
      ],
    );
  }

  // ──────────────────── Common widgets ────────────────────

  Widget _buildEmptyState(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AiraColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            text,
            style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
