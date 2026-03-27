# Company Configuration Templates

These JSON files are starter templates for admin uploads in the **Admin Panel**.

## Upload workflow
1. Edit `rate_card_template.json` per company + policy type/subtype.
2. Edit `quote_template.json` per company + policy type/subtype.
3. In the app Admin Panel, use:
   - **Upload Rate Card JSON**
   - **Upload Quote Template JSON**

Both documents are stored in Firestore and used by quote generation:
- `company_rate_cards/{companyId}_{insuranceType}_{insuranceSubtype}`
- `company_quote_templates/{companyId}_{insuranceType}_{insuranceSubtype}`
