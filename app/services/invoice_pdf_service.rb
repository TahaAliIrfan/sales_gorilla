# frozen_string_literal: true

require 'prawn'
require 'prawn/table'
begin
  require 'prawn-svg'
  PRAWN_SVG_AVAILABLE = true
rescue LoadError
  PRAWN_SVG_AVAILABLE = false
end

Prawn::Fonts::AFM.hide_m17n_warning = true

class InvoicePdfService
  RED_COLOR = "ED1A3B"
  BLACK_COLOR = "000000"
  WHITE_COLOR = "FFFFFF"
  GRAY_COLOR = "666666"

  def initialize(invoice)
    @invoice = invoice
    @customer = invoice.customer
  end

  def generate_pdf
    Prawn::Document.new(page_size: 'A4', margin: [40, 60]) do |pdf|
      add_header(pdf)
      add_customer_section(pdf)
      add_line_items_table(pdf)
      add_totals_section(pdf)
      add_footer(pdf)
    end
  end

  private

  def add_header(pdf)
    # Logo and title row
    logo_path = Rails.root.join('public', 'tecaudex.svg')
    if PRAWN_SVG_AVAILABLE && File.exist?(logo_path) && pdf.respond_to?(:svg)
      begin
        pdf.svg File.read(logo_path), width: 60, height: 60
        pdf.move_down 60
      rescue => e
        Rails.logger.warn("Could not render SVG logo: #{e.message}")
      end
    end

    pdf.font "Helvetica"
    pdf.font_size 24
    pdf.fill_color BLACK_COLOR
    pdf.text "INVOICE", style: :bold
    pdf.move_down 20

    # Invoice details
    pdf.font_size 10
    pdf.fill_color GRAY_COLOR
    pdf.text "Invoice #: #{sanitize(@invoice.invoice_number)}"
    pdf.text "Issue Date: #{@invoice.issue_date.strftime('%B %d, %Y')}"
    pdf.text "Due Date: #{@invoice.due_date.strftime('%B %d, %Y')}"
    pdf.move_down 20
  end

  def add_customer_section(pdf)
    pdf.font_size 11
    pdf.fill_color BLACK_COLOR
    pdf.text "Bill To", style: :bold
    pdf.move_down 5
    pdf.font_size 10
    pdf.fill_color GRAY_COLOR
    pdf.text sanitize(@customer.name)
    pdf.text sanitize(@customer.company) if @customer.company.present?
    pdf.text sanitize(@customer.email) if @customer.email.present?
    pdf.text sanitize(@customer.address) if @customer.address.present?
    pdf.move_down 25
  end

  def add_line_items_table(pdf)
    pdf.font_size 10
    pdf.fill_color BLACK_COLOR

    table_data = [["Description", "Amount"]]
    @invoice.invoice_line_items.each do |item|
      table_data << [sanitize(item.description), number_to_currency(item.amount)]
    end

    pdf.table(
      table_data,
      header: true,
      row_colors: ["FFFFFF", "F9FAFB"],
      cell_style: { padding: 8 },
      column_widths: [pdf.bounds.width - 120, 100]
    ) do
      row(0).font_style = :bold
      row(0).background_color = "1F2937"
      row(0).text_color = WHITE_COLOR
    end

    pdf.move_down 20
  end

  def add_totals_section(pdf)
    subtotal = @invoice.subtotal
    tax_amount = @invoice.tax_amount
    total = @invoice.total

    totals_width = 150
    totals_x = pdf.bounds.width - totals_width - 20

    pdf.font_size 10
    pdf.fill_color GRAY_COLOR
    pdf.text_box "Subtotal:", at: [totals_x - 80, pdf.cursor], width: 80
    pdf.text_box number_to_currency(subtotal), at: [totals_x, pdf.cursor], width: totals_width, align: :right
    pdf.move_down 20

    if tax_amount.to_f > 0
      pdf.text_box "Tax (#{@invoice.tax_rate}%):", at: [totals_x - 80, pdf.cursor], width: 80
      pdf.text_box number_to_currency(tax_amount), at: [totals_x, pdf.cursor], width: totals_width, align: :right
      pdf.move_down 20
    end

    pdf.font_size 12
    pdf.fill_color BLACK_COLOR
    pdf.text_box "Total:", at: [totals_x - 80, pdf.cursor], width: 80, style: :bold
    pdf.text_box number_to_currency(total), at: [totals_x, pdf.cursor], width: totals_width, align: :right, style: :bold
    pdf.move_down 30
  end

  def add_footer(pdf)
    pdf.font_size 9
    pdf.fill_color GRAY_COLOR
    pdf.stroke_color RED_COLOR
    pdf.line_width 1
    pdf.stroke_horizontal_rule
    pdf.move_down 15
    pdf.text "Thank you for your business.", align: :center
    pdf.text "Tecaudex", align: :center, style: :bold
  end

  def sanitize(text)
    text.to_s.gsub(/[^\x20-\x7E]/, '')
  end

  def number_to_currency(amount)
    "$#{amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
