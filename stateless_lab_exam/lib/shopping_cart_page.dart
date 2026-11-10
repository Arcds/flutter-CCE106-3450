import 'package:flutter/material.dart';

/// A static shopping cart screen built entirely with [StatelessWidget]s.
class ShoppingCartPage extends StatelessWidget {
  const ShoppingCartPage({super.key});

  // Shared colors used across the page.
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color softBlue = Color(0xFFE8F0FE);
  static const Color pageBackground = Color(0xFFF3F5F9);
  static const Color titleColor = Color(0xFF111827);
  static const Color mutedColor = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: titleColor),
          tooltip: 'Back',
          onPressed: () => debugPrint('Back clicked'),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        actions: const [
          _CartIconButton(),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _IntroductionSection(),
              SizedBox(height: 16),
              _DeliveryCard(),
              SizedBox(height: 20),
              _OrderItemsHeader(),
              SizedBox(height: 12),
              CartItemCard(
                productName: 'Wireless Mouse',
                price: 'PHP 450.00',
                quantity: 1,
                icon: Icons.mouse_outlined,
              ),
              SizedBox(height: 12),
              CartItemCard(
                productName: 'USB-C Hub',
                price: 'PHP 850.00',
                quantity: 1,
                icon: Icons.usb,
              ),
              SizedBox(height: 12),
              CartItemCard(
                productName: 'Laptop Stand',
                price: 'PHP 700.00',
                quantity: 1,
                icon: Icons.laptop_mac_outlined,
              ),
              SizedBox(height: 20),
              _DiscountBanner(),
              SizedBox(height: 20),
              _PaymentSummary(),
              SizedBox(height: 20),
              _PlaceOrderButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shopping bag icon with a "3" badge positioned using a [Stack].
class _CartIconButton extends StatelessWidget {
  const _CartIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => debugPrint('Cart clicked'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            color: ShoppingCartPage.titleColor,
            size: 26,
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: ShoppingCartPage.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '3',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Light-blue intro block with the store tag, heading and supporting text.
class _IntroductionSection extends StatelessWidget {
  const _IntroductionSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD7E6FD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'CAMPUS STORE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: ShoppingCartPage.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ready for checkout',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: ShoppingCartPage.titleColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review your items before placing your order.',
            style: TextStyle(fontSize: 13, color: ShoppingCartPage.mutedColor),
          ),
        ],
      ),
    );
  }
}

/// White card showing the delivery address with a "Change" action.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShoppingCartPage.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShoppingCartPage.softBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: ShoppingCartPage.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deliver to Arche Tigbabao',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ShoppingCartPage.titleColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Matina, Davao City',
                  style: TextStyle(
                    fontSize: 12,
                    color: ShoppingCartPage.mutedColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => debugPrint('Change delivery address clicked'),
            style: TextButton.styleFrom(
              foregroundColor: ShoppingCartPage.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Order Items" heading paired with the fixed item count.
class _OrderItemsHeader extends StatelessWidget {
  const _OrderItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Order Items',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ShoppingCartPage.titleColor,
          ),
        ),
        Text(
          '3 items',
          style: TextStyle(fontSize: 12, color: ShoppingCartPage.mutedColor),
        ),
      ],
    );
  }
}

/// Reusable product card used for every item in the cart.
class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.icon,
  });

  final String productName;
  final String price;
  final int quantity;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShoppingCartPage.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ShoppingCartPage.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: ShoppingCartPage.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ShoppingCartPage.titleColor,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove item',
                      onPressed: () =>
                          debugPrint('Remove item: $productName'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: ShoppingCartPage.mutedColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ShoppingCartPage.primaryBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      tooltip: 'Decrease quantity',
                      onPressed: () =>
                          debugPrint('Decrease quantity: $productName'),
                    ),
                    Container(
                      width: 40,
                      height: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFBFD4F7),
                        ),
                      ),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: ShoppingCartPage.titleColor,
                        ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add,
                      tooltip: 'Increase quantity',
                      onPressed: () =>
                          debugPrint('Increase quantity: $productName'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small square minus/plus control used by [CartItemCard].
class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFFF5F8FF),
          side: const BorderSide(color: Color(0xFFBFD4F7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Icon(
          icon,
          size: 16,
          color: ShoppingCartPage.primaryBlue,
        ),
      ),
    );
  }
}

/// Light-blue banner advertising the applied student discount.
class _DiscountBanner extends StatelessWidget {
  const _DiscountBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            color: ShoppingCartPage.primaryBlue,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STUDENT10 applied',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '10% discount on items',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3B5B8C),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: ShoppingCartPage.primaryBlue,
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// White card listing subtotal, discount, delivery fee and total.
class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShoppingCartPage.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ShoppingCartPage.titleColor,
            ),
          ),
          const SizedBox(height: 14),
          const _SummaryRow(label: 'Subtotal', amount: 'PHP 2,000.00'),
          const SizedBox(height: 10),
          const _SummaryRow(
            label: 'Discount (10%)',
            amount: '- PHP 200.00',
            amountColor: ShoppingCartPage.primaryBlue,
          ),
          const SizedBox(height: 10),
          const _SummaryRow(label: 'Delivery Fee', amount: 'PHP 50.00'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: ShoppingCartPage.borderColor),
          ),
          const _SummaryRow(
            label: 'Total',
            amount: 'PHP 1,850.00',
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// A single label/amount row inside the payment summary.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    this.amountColor = ShoppingCartPage.titleColor,
    this.emphasized = false,
  });

  final String label;
  final String amount;
  final Color amountColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 15 : 13,
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            color: emphasized
                ? ShoppingCartPage.titleColor
                : ShoppingCartPage.mutedColor,
          ),
        ),
        Flexible(
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 15 : 13,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
              color: emphasized ? ShoppingCartPage.titleColor : amountColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width primary action button.
class _PlaceOrderButton extends StatelessWidget {
  const _PlaceOrderButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () =>
            debugPrint('Place order clicked! Total: PHP 1850.00'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ShoppingCartPage.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.lock_outline, size: 18, color: Colors.white),
        label: const Text(
          'Place Order',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
