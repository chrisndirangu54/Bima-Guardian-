# Company Configuration Templates

These files define admin upload formats for company-specific pricing and quote output.

## Exact visual match mode (recommended for quote docs)
To keep the final quote visually identical to the admin-uploaded document:
1. Upload a quote PDF layout via Admin PDF template workflow (same way PDF templates are handled).
2. In the quote template JSON, set:
   - `pdfTemplateKey`: uploaded PDF template key
   - `useOriginalLayout`: `true`
3. The quote generator overlays calculated fields on top of the original rendered PDF pages.

## Supported admin upload source formats
- Rate card source: `json`, `csv`, `txt`, `pdf`, `doc`, `docx`, `ppt`, `pptx`, `xls`, `xlsx`
- Quote source: `json`, `txt`, `pdf`, `doc`, `docx`, `ppt`, `pptx`, `xls`, `xlsx`

## Conversion behavior
1. Admin uploads a source file in **Admin Panel**.
2. The raw source is saved to Firebase Storage (`company_uploads/...`).
3. A conversion record is saved to Firestore (`company_upload_conversions`).
4. If upload is `json/csv/txt` (rate card) or `json/txt` (quote), conversion is immediate.
5. For Office/PDF uploads, status is `queued_for_conversion` for downstream extraction workers.

## Firestore targets
- Rate cards: `company_rate_cards/{companyId}_{insuranceType}_{insuranceSubtype}`
- Quote templates: `company_quote_templates/{companyId}_{insuranceType}_{insuranceSubtype}`
- Conversion queue/log: `company_upload_conversions/{autoDocId}`
