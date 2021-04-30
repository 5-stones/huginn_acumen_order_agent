# frozen_string_literal: true

# This module is responsible for reading/processing the Invoice_Detail table. This table
# contains information related to individual line items within an invoice.
module InvoiceDetailQueryConcern
  extend AcumenOrderQueryConcern

  # Update the provided products with their associated marketing data
  # NOTE: The `products` here are Shema.org/Product records mapped from Inv_Product
  # data
  def fetch_invoice_details(acumen_client, invoices)

    invoice_ids = invoices.map { |p| p['identifier'] }
    line_item_data = acumen_client.get_invoice_details(invoice_ids)
    line_item_data = process_invoice_detail_response(line_item_data)

    return map_line_item_data(invoices, line_item_data)
  end

  # This function parses the raw data returned from the Prod_Mkt table
  def process_invoice_detail_response(raw_data)
    results = []
    raw_data.each do |invoice_details|

      begin
        mapped_item = response_mapper(invoice_details, {
          'Invoice_Detail.Invoice_DETAIL_ID' => 'id',
          'Invoice_Detail.Title' => 'title',
          'Invoice_Detail.ProdCode' => 'sku',
          'Invoice_Detail.Ordered' => 'quantity_ordered',
          'Invoice_Detail.Ship' => 'quantity_shipped',
          'Invoice_Detail.BO' => 'quantity_backordered',
          'Invoice_Detail.BO_Reason' => 'bo_reason',
          'Invoice_Detail.BO_Prebill' => 'is_prebill',
          'Invoice_Detail.Invoice_ID' => 'invoice_id',
          'Invoice_Detail.Modified_Date' => 'modified_date',
          'Invoice_Detail.BO_Original_Invoice_DETAIL_ID' => 'bo_original_detail_id',

        })

        results << mapped_item
      rescue => error
        issue_error(AcumenOrderError.new(
          500,
          'process_invoice_detail_response',
          'Failed while processing Invoice_Detail record',
          { invoice_details_id: get_field_value(invoice_details, 'Invoice_Detail.Invoice_DEATAIL_ID') },
          error,
        ))
      end
    end

    results
  end

  # This function maps parsed Invoice_Detail records to their matching Invoice record
  # and updates the invoice object with the additional data
  def map_line_item_data(invoices, line_item_data)

    # acceptedOffer
    #   identifier
    #   sku
    #   price
    #   priceCurrency
    #   name

    invoices.map do |invoice|
      items = line_item_data.select { |item| item['invoice_id'] == invoice['identifier'] }

      begin
        unless items.blank?
          invoice['acceptedOffer'] = items.map do |i|
            item = {
              '@type' => 'Offer',
              'identifier' => i['identifier'],
              'sku' => i['sku'],
              'name' => i['title'],
              'acumenAttributes' => {},
              'modifiedDate' => i['modified_date'],
              'invoiceDetailID' => i['id'],
              'boOriginalDetailId' => i['bo_original_detail_id'],
            }

            #----------  Acumen Specific Properties  ----------#
            item['acumenAttributes']['quantity_ordered'] = i['quantity_ordered']
            item['acumenAttributes']['quantity_shipped'] = i['quantity_shipped']
            item['acumenAttributes']['quantity_backordered'] = i['quantity_backordered']

            item
          end
        end
      rescue => error
        issue_error(AcumenOrderError.new(
          500,
          'map_line_item_data',
          'Failed to map line item data for invoice',
          {
            invoice_id: invoice['identifier'],
            line_item_ids: items.map { |p|
              { id: p['identifier'], sku: p['sku'] }
            }
          },
          error,
        ))
      end

      invoice
    end
  end
end
