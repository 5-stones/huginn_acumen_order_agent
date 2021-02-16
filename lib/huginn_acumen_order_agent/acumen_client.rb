class AcumenOrderClient
  @faraday
  @auth

  def initialize(faraday, auth)
    @faraday = faraday
    @auth = auth
  end

  def get_invoices(order_codes)
      body = build_invoice_request(order_codes)
      response = execute_in_list_query(body, {})
      get_results(response, 'Invoice')
  end

  def get_invoice_details(invoice_ids)
      body = build_invoice_detail_query(invoice_ids)
      response = execute_in_list_query(body, {})
      get_results(response, 'Invoice_Detail')
  end

  def execute_query(body, headers)
      response = @faraday.run_request(:post, "#{@auth['endpoint']}Query", body, headers)
      ::MultiXml.parse(response.body, {})
  end

  def execute_in_list_query(body, headers)
      response = @faraday.run_request(:post, "#{@auth['endpoint']}QueryByInList", body, headers)
      ::MultiXml.parse(response.body, {})
  end

  def get_results(response, name)
      result_set = response['Envelope']['Body']['acusoapResponse']['result_set.' + name]
      results = result_set.nil? ? [] : result_set[name]
      results.is_a?(Array) ? results : [results]
  end

  private

  def build_invoice_request(codes)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>Invoice.Order_Code</column_name>
                  <comparator>in</comparator>
                  <value>#{codes.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                  <view_owner_table_name>Invoice</view_owner_table_name>
                  <view_name>InvoiceAllRead</view_name>
                  <column_name>Invoice.Invoice_ID</column_name>
                  <column_name>Invoice.Modified_Date</column_name>
                  <column_name>Invoice.Order_Code</column_name>
                  <column_name>Invoice.Order_Date</column_name>
                  <column_name>Invoice.Status</column_name>
                  <column_name>Invoice.Customer_Name</column_name>
                  <column_name>Invoice.Tracking_Num</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_invoice_detail_query(invoice_ids)
      <<~XML
          <acusoapRequest>
              #{build_acumen_query_auth()}
              <query>
                <statement>
                  <column_name>Invoice_Detail.Invoice_ID</column_name>
                  <comparator>in</comparator>
                  <value>#{invoice_ids.join(',')}</value>
                </statement>
              </query>
              <requested_output>
                <view_owner_table_name>Invoice_Detail</view_owner_table_name>
                <view_name>Invoice_DetailAllRead</view_name>
                <column_name>Invoice_Detail.Invoice_DETAIL_ID</column_name>
                <column_name>Invoice_Detail.Title</column_name>
                <column_name>Invoice_Detail.ProdCode</column_name>
                <column_name>Invoice_Detail.Ordered</column_name>
                <column_name>Invoice_Detail.Ship</column_name>
                <column_name>Invoice_Detail.BO</column_name>
                <column_name>Invoice_Detail.List</column_name>
                <column_name>Invoice_Detail.Back_Order_ID</column_name>
                <column_name>Invoice_Detail.Mktg_Code</column_name>
                <column_name>Invoice_Detail.Order_Number</column_name>
                <column_name>Invoice_Detail.BO_Reason</column_name>
                <column_name>Invoice_Detail.Quant_Ship_Confirm</column_name>
                <column_name>Invoice_Detail.Quant_BO_Confirm</column_name>
                <column_name>Invoice_Detail.BO_Prebill</column_name>
                <column_name>Invoice_Detail.Back_Order_Special_ID</column_name>
                <column_name>Invoice_Detail.PO_Number</column_name>
                <column_name>Invoice_Detail.RF_ShipConfirm_Comment</column_name>
                <column_name>Invoice_Detail.Old_BO</column_name>
                <column_name>Invoice_Detail.Invoice_ID</column_name>
                <column_name>Invoice_Detail.Modified_Date</column_name>
                <column_name>Invoice_Detail.BO_Original_Invoice_DETAIL_ID</column_name>
              </requested_output>
          </acusoapRequest>
      XML
  end

  def build_acumen_query_auth()
      <<~XML
          <authentication>
            <site_code>#{@auth['site_code']}</site_code>
            <password>#{@auth['password']}</password>
          </authentication>
          <message_version>1.00</message_version>
      XML
  end

end
