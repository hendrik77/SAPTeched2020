CLASS lhc_inventory DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateinventoryid FOR DETERMINE ON SAVE
      IMPORTING keys FOR inventory~calculateinventoryid.
    METHODS getprice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR inventory~getprice.

ENDCLASS.

CLASS lhc_inventory IMPLEMENTATION.

  METHOD calculateinventoryid.

    "Ensure idempotence
    READ ENTITIES OF zi_rap_inventory_174 IN LOCAL MODE
      ENTITY inventory
        FIELDS ( inventoryid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(inventories).

    DELETE inventories WHERE inventoryid IS NOT INITIAL.
    CHECK inventories IS NOT INITIAL.

    "Get max travelID
    SELECT SINGLE FROM zrap_inven_174 FIELDS MAX( inventory_id ) INTO @DATA(max_inventory).

    "update involved instances
    MODIFY ENTITIES OF zi_rap_inventory_174 IN LOCAL MODE
      ENTITY inventory
        UPDATE FIELDS ( inventoryid )
        WITH VALUE #( FOR inventory IN inventories INDEX INTO i (
                           %tky      = inventory-%tky
                           inventoryid  = max_inventory + i ) )
    REPORTED DATA(lt_reported).

    "fill reported
    reported = CORRESPONDING #( DEEP lt_reported ).

  ENDMETHOD.

  METHOD getprice.
    DATA destination  TYPE REF TO if_soap_destination.
    DATA proxy TYPE REF TO zrap_174_co_epm_product_soap .
    DATA reported_inventory_soap LIKE reported-inventory.

    "Ensure idempotence
    READ ENTITIES OF zi_rap_inventory_174 IN LOCAL MODE
      ENTITY inventory
        FIELDS ( price productid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(inventories).

    DELETE inventories WHERE price IS NOT INITIAL.
    CHECK inventories IS NOT INITIAL.

    DELETE inventories WHERE productid = ''.
    CHECK inventories IS NOT INITIAL.

    LOOP AT inventories ASSIGNING FIELD-SYMBOL(<inventory>).

      TRY.

          IF destination IS INITIAL.
            destination = cl_soap_destination_provider=>create_by_url( i_url = 'https://sapes5.sapdevcenter.com/sap/bc/srt/xip/sap/zepm_product_soap/002/epm_product_soap/epm_product_soap' ).
          ENDIF.
          IF proxy IS INITIAL.
            proxy = NEW zrap_174_co_epm_product_soap( destination = destination ).
          ENDIF.

          DATA(request) = VALUE zrap_174_req_msg_type( req_msg_type-product = <inventory>-productid ).
          proxy->get_price(
            EXPORTING
              input = request
            IMPORTING
              output = DATA(response) ).

          <inventory>-price = response-res_msg_type-price .
          <inventory>-currencycode = response-res_msg_type-currency.

          "handle response
        CATCH cx_soap_destination_error INTO DATA(soap_destination_error).
          DATA(error_message) = soap_destination_error->get_text(  ).
        CATCH cx_ai_system_fault INTO DATA(ai_system_fault).
          error_message = | code: { ai_system_fault->code  } codetext: { ai_system_fault->codecontext  }  |.
        CATCH zrap_174_cx_fault_msg_type INTO DATA(soap_exception).
          error_message = soap_exception->error_text.
          "fill reported structure to be displayed on the UI
          APPEND VALUE #( uuid = <inventory>-uuid
                          %msg = new_message( id = 'ZCM_RAP_GENERATOR'
                                              number = '016'
                                              v1 = error_message
                                              severity = CONV #( 'E' ) )
                           %element-price = if_abap_behv=>mk-on ) TO reported_inventory_soap.
          "inventory entries where no price could be retrieved must not be passed to the MODIFY statement
          DELETE inventories INDEX sy-tabix.
      ENDTRY.

    ENDLOOP.

    "update involved instances
    MODIFY ENTITIES OF zi_rap_inventory_174 IN LOCAL MODE
      ENTITY inventory
        UPDATE FIELDS ( price currencycode )
        WITH VALUE #( FOR inventory IN inventories (
                           %tky      = inventory-%tky
                           price  = inventory-price
                           currencycode  = inventory-currencycode ) )
      REPORTED DATA(reported_entities).

    "fill reported
    reported = CORRESPONDING #( DEEP reported_entities ).

    "add reported from SOAP call
    LOOP AT reported_inventory_soap INTO DATA(reported_inventory).
      APPEND reported_inventory TO reported-inventory.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
