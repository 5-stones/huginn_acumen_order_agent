require 'huginn_agent'

HuginnAgent.load 'huginn_acumen_order_agent/concerns/acumen_query_concern'
HuginnAgent.load 'huginn_acumen_order_agent/concerns/invoice_query_concern'
HuginnAgent.load 'huginn_acumen_order_agent/concerns/invoice_detail_query_concern'

HuginnAgent.load 'huginn_acumen_order_agent/acumen_client'
HuginnAgent.load 'huginn_acumen_order_agent/acumen_order_error'

HuginnAgent.register 'huginn_acumen_order_agent/acumen_order_agent'
