# frozen_string_literal: true

# This module is responsible for reading/processing data recrods from the Invoice
# table in Acumen. This table contains the baseline order/shipment information
# Shipping method, tracking numbers, etc.
module InvoiceQueryConcern
  extend AcumenOrderQueryConcern

  # Fetch/Process the Acumen data,
  def fetch_invoice_data(acumen_client, order_codes)
    invoice_data = acumen_client.get_invoices(order_codes)

    return process_invoice_response(invoice_data)
  end

  # This function returns an array of Acumen invoices.
  def process_invoice_response(raw_data)
    raw_data.map do |i|

      log('------------------------------------------------------------')
          log(":: raw invoice #{i}")
      log('------------------------------------------------------------')

      invoice = nil
      begin
        invoice = response_mapper(i, {
          'Invoice.Invoice_ID' => 'identifier',
          'Invoice.Order_Code' => 'orderNumber',
          'Invoice.Order_Date' => 'orderDate',
          'Invoice.Status' => 'orderStatus',
          'Invoice.Customer_Name' => 'customer',
          'Invoice.Modified_Date' => 'modified_date',
        })

        invoice['type'] = '@Order'

        #----------  Parse Tracking Numbers  ----------#
        invoice['orderDelivery'] = []
        tracking_numbers = get_field_value(i, 'Invoice.Tracking_Num')
        tracking_numbers = tracking_numbers.blank? ? [] : tracking_numbers.split(/\s|&#13;/)

        tracking_numbers.map do |tn|
          invoice['orderDelivery'] << {
            'type' => '@ParcelDelivery',
            'trackingNumber' => tn,
          }
        end

      rescue => error
        issue_error(AcumenOrderError.new(
          500,
          'process_invoice_response',
          'Failed to load invoice records',
          { invoice_id: get_field_value(i, 'Invoice.Invoice_ID') },
          error,
        ))
      end

      log('------------------------------------------------------------')
          log(":: parsed invoice #{invoice}")
      log('------------------------------------------------------------')

      invoice
    end
  end

end
