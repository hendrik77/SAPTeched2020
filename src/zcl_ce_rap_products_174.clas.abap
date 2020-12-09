CLASS zcl_ce_rap_products_174 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    INTERFACES if_rap_query_provider.

    TYPES t_product_range TYPE RANGE OF zrap_174_sepmra_i_product_e-product.
    TYPES t_business_data TYPE TABLE OF zrap_174_sepmra_i_product_e.

    METHODS get_products
      IMPORTING
        it_filter_cond   TYPE if_rap_query_filter=>tt_name_range_pairs OPTIONAL
        top              TYPE i OPTIONAL
        skip             TYPE i OPTIONAL
      EXPORTING
        et_business_data TYPE  t_business_data
      RAISING
        /iwbep/cx_cp_remote
        /iwbep/cx_gateway
        cx_web_http_client_error
        cx_http_dest_provider_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ce_rap_products_174 IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA(ranges_table) = VALUE if_rap_query_filter=>tt_range_option( (  sign = 'I' option = 'GE' low = 'HT-1200' ) ).
    DATA(filter_conditions) = VALUE if_rap_query_filter=>tt_name_range_pairs( ( name = 'PRODUCT'  range = ranges_table ) ).

    TRY.
        DATA business_data TYPE TABLE OF zrap_174_sepmra_i_product_e.
        get_products(
          EXPORTING
            it_filter_cond    = filter_conditions
            top               =  3
            skip              =  1
          IMPORTING
            et_business_data  = business_data ).
        out->write( business_data ).
      CATCH cx_root INTO DATA(exception).
        out->write( cl_message_helper=>get_latest_t100_exception( exception )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_products.
    DATA(http_destination) = cl_http_destination_provider=>create_by_url( i_url = 'https://sapes5.sapdevcenter.com' ).
    DATA(http_client) = cl_web_http_client_manager=>create_by_http_destination( i_destination = http_destination ).

    DATA(odata_client_proxy) = cl_web_odata_client_factory=>create_v2_remote_proxy(
        iv_service_definition_name = 'ZSC_RAP_PRODUCTS_174'
        io_http_client             = http_client
        iv_relative_service_root   = '/sap/opu/odata/sap/ZPDCDS_SRV/' ).

    " Navigate to the resource and create a request for the read operation
    DATA(read_list_request) = odata_client_proxy->create_resource_for_entity_set( 'SEPMRA_I_PRODUCT_E' )->create_request_for_read( ).

    " Create the filter tree
    DATA(filter_factory) = read_list_request->create_filter_factory( ).
    DATA root_filter_node TYPE REF TO /iwbep/if_cp_filter_node.
    LOOP AT  it_filter_cond  INTO DATA(filter_condition).
      DATA(filter_node)  = filter_factory->create_by_range( iv_property_path = filter_condition-name
                                                            it_range = filter_condition-range ).
      IF root_filter_node IS INITIAL.
        root_filter_node = filter_node.
      ELSE.
        root_filter_node = root_filter_node->and( filter_node ).
      ENDIF.
    ENDLOOP.

    IF root_filter_node IS NOT INITIAL.
      read_list_request->set_filter( root_filter_node ).
    ENDIF.

    IF top > 0 .
      read_list_request->set_top( top ).
    ENDIF.

    read_list_request->set_skip( skip ).

    " Execute the request and retrieve the business data
    DATA(read_list_response) = read_list_request->execute( ).
    read_list_response->get_business_data( IMPORTING et_business_data = et_business_data ).

  ENDMETHOD.

  METHOD if_rap_query_provider~select.
    DATA(top) = io_request->get_paging( )->get_page_size( ).
    DATA(skip) = io_request->get_paging( )->get_offset( ).
    DATA(requested_fields)  = io_request->get_requested_elements( ).
    DATA(sort_order) = io_request->get_sort_elements( ).

    TRY.
        DATA(filter_condition) = io_request->get_filter( )->get_as_ranges( ).

        get_products(
                 EXPORTING
                   it_filter_cond    = filter_condition
                   top               = CONV i( top )
                   skip              = CONV i( skip )
                 IMPORTING
                   et_business_data  = DATA(business_data) ) .

        io_response->set_total_number_of_records( lines( business_data ) ).
        io_response->set_data( business_data ).

      CATCH cx_root INTO DATA(exception).
        DATA(exception_message) = cl_message_helper=>get_latest_t100_exception( exception )->if_message~get_longtext( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
