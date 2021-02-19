# frozen_string_literal: true

module Agents
    class AcumenOrderAgent < Agent
        include WebRequestConcern
        include AcumenOrderQueryConcern
        include InvoiceQueryConcern
        include InvoiceDetailQueryConcern

        default_schedule '12h'

        can_dry_run!
        default_schedule 'never'

        description <<-MD
        Huginn agent for retrieving sane ACUMEN invoice data.

        ## Agent Options
        The following outlines the available options in this agent

        ### Acumen Connection
        * endpoint: The root URL for the Acumen API
        * site_code: The site code from Acumen
        * password: The Acumen API password
        * output_mode  - not required ('clean' or 'merge', defaults to 'clean')

        ### Payload Status

        `status: 200`: Indicates a true success. The agent has output the full
        range of expected data.

        `status: 206`: Indicates a partial success. The products within the bundle
        are vaild, but the bundle _may_ be missing products that were somehow invalid.

        `status: 500`: Indicates a processing error. This may represent a complete
        process failure, but may also be issued in parallel to a `202` payload.

        Because this agent receives an array of Order Codes as input, errors will be issued in
        such a way that product processing can recover when possible. Errors that occur within
        a specific product bundle will emit an error event, but the agent will then move
        forward processing the next bundle.

        For example, if this agent receives two products as input (`A` and `B`), and we fail to
        load the Inv_Product record for product `A`, the agent would emit an error payload of:

        ```
        {
          status: 500,
          scope: 'Fetch Inv_Product Data',
          message: 'Failed to lookup Inv_Product record for Product A',
          data: { product_id: 123 },
          trace: [ ... ]
        }
        ```

        The goal of this approach is to ensure the agent outputs as much data as reasonably possible
        with each execution. If there is an error in the Paperback version of a title, that shouldn't
        prevent this agent from returning the Hardcover version.

        MD

        def default_options
            {
                'endpoint' => 'https://example.com',
                'site_code' => '',
                'password' => '',
                'output_mode' => 'clean',
            }
        end

        def validate_options
            unless options['endpoint'].present?
                errors.add(:base, 'endpoint is a required field')
            end

            unless options['site_code'].present?
                errors.add(:base, 'site_code is a required field')
            end

            unless options['password'].present?
                errors.add(:base, 'password is a required field')
            end

            if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
              errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
            end
        end

        def working?
            received_event_without_error?
        end

        def check
            handle interpolated['payload'].presence || {}
        end

        def receive(incoming_events)
            incoming_events.each do |event|
                handle(event)
            end
       end

        private

        def handle(event)
            # Process agent options
            endpoint = interpolated['endpoint']
            endpoint = endpoint += '/' unless endpoint.end_with?('/')
            site_code = interpolated['site_code']
            password = interpolated['password']

            # Configure the Acumen Client
            auth = {
                'site_code' => site_code,
                'password' => password,
                'endpoint' => endpoint,
            }
            client = AcumenOrderClient.new(faraday, auth)
            data = event.payload
            order_codes = event.payload['order_codes']
            new_event = interpolated['output_mode'].to_s == 'merge' ? data.dup : {}

            begin
              invoices = fetch_invoice_data(client, order_codes)

              unless invoices.blank?
                invoices = fetch_invoice_details(client, invoices)
                create_event payload: new_event.merge(
                  invoices: invoices,
                  status: 200
                )
              end
            rescue AcumenOrderError => e
              issue_error(e, new_event)
            end
        end

        def issue_error(error, new_event, status = 500)
          # NOTE: Status is intentionally included on the top-level payload so that other
          # agents can look for a `payload[:status]` of either 200 or 500 to distinguish
          # between success and failure states
          create_event payload: new_event.merge(
            status: status,
            scope: error.scope,
            message: error.message,
            original_error: error.original_error,
            data: error.data,
            trace: error.original_error.backtrace,
          )
        end

    end
end
