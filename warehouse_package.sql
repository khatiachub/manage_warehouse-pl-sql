prompt PL/SQL Developer Export User Objects for user KHATIA@ORCL
prompt Created by xatia on Tuesday, May 13, 2025
set define off
spool warehouse_package.log

prompt
prompt Creating package body PKG_WAREHOUSE_PRODUCT_MANAGMENT
prompt =====================================================
prompt
create or replace package body khatia.pkg_warehouse_product_managment is
  procedure proc_entry_products(p_barcode        varchar2,
                                p_product_name   varchar2,
                                p_quantity       number,
                                p_entry_date     varchar2,
                                p_operator_id    number,
                                p_warehouse_name varchar2) as
    v_count number;
  
  begin
    select count(*)
      into v_count
      from khatia_warehouse_exchanges
     where barcode = p_barcode
       and product_name != p_product_name;
  
    if v_count > 0 then
      RAISE_APPLICATION_ERROR(-20001,
                              'A product with this barcode already exists.');
    else
      insert into khatia_warehouse_exchanges
        (barcode,
         product_name,
         quantity,
         entry_date,
         operator_id,
         warehouse_name)
      values
        (p_barcode,
         p_product_name,
         p_quantity,
         TO_DATE(p_entry_date, 'DD-Mon-YYYY'),
         p_operator_id,
         p_warehouse_name);
    end if;
  end proc_entry_products;

  procedure proc_get_all_entry_products(p_company_id   number,
                                        p_product_curs OUT SYS_REFCURSOR) as
  begin
    open p_product_curs for
      select w.barcode,
             w.product_name,
             w.quantity,
             w.entry_date,
             u.name,
             u.lastname,
             w.warehouse_name
        from khatia_warehouse_exchanges w
       inner join khatia_users u
          on u.id = w.operator_id
       where exit_date is null
         and p_company_id = u.company_id;
  end proc_get_all_entry_products;

  procedure proc_get_entry_product(p_id           number,
                                   p_product_curs OUT SYS_REFCURSOR) as
  begin
    open p_product_curs for
      select w.id,
             w.barcode,
             w.product_name,
             w.quantity,
             w.entry_date,
             u.name,
             u.lastname,
             w.warehouse_name
        from khatia_warehouse_exchanges w
       inner join khatia_users u
          on u.id = w.operator_id
       where w.exit_date is null
         and p_id = u.warehouse_id;
  end proc_get_entry_product;

  procedure proc_update_entry_product(p_barcode      varchar2,
                                      p_product_name varchar2,
                                      p_quantity     number,
                                      p_entry_date   varchar2,
                                      p_id           varchar2) is
  begin
    update khatia_warehouse_exchanges
       set barcode      = p_barcode,
           product_name = p_product_name,
           quantity     = p_quantity,
           entry_date   = p_entry_date
     where id = p_id;
  end proc_update_entry_product;

  procedure proc_exit_products(p_barcode        varchar2,
                               p_product_name   varchar2,
                               p_quantity       number,
                               p_exit_date      varchar2,
                               p_operator_id    number,
                               p_warehouse_name varchar2,
                               p_unit           varchar2) as
    v_available_quantity number;
  begin
    select SUM(case
                 when e.entry_date is not null and e.exit_date is null then
                  e.quantity
                 when e.exit_date is not null then
                  -e.quantity
                 else
                  0
               end) AS current_balance
      into v_available_quantity
      from khatia_warehouse_exchanges e
     where e.barcode = p_barcode
       and e.warehouse_name = p_warehouse_name
     group by e.barcode, e.product_name, e.warehouse_name;
  
    if NVL(v_available_quantity, 0) >= p_quantity then
      insert into khatia_warehouse_exchanges
        (barcode,
         product_name,
         quantity,
         exit_date,
         operator_id,
         warehouse_name,
         unit)
      values
        (p_barcode,
         p_product_name,
         p_quantity,
         TO_DATE(p_exit_date, 'DD-Mon-YYYY'),
         p_operator_id,
         p_warehouse_name,
         p_unit);
    else
      RAISE_APPLICATION_ERROR(-20001,
                              'Not enough quantity available for exit.');
    end if;
  end proc_exit_products;

  procedure proc_get_all_exit_products(p_company_id   number,
                                       p_product_curs OUT SYS_REFCURSOR) as
  begin
    open p_product_curs for
      select w.barcode,
             w.product_name,
             w.quantity,
             w.exit_date,
             u.name,
             u.lastname,
             w.warehouse_name
        from khatia_warehouse_exchanges w
       inner join khatia_users u
          on u.id = w.operator_id
       where exit_date is not null
         and p_company_id = u.company_id;
  end proc_get_all_exit_products;

  procedure proc_get_exit_product(p_id           number,
                                  p_product_curs OUT SYS_REFCURSOR) as
  begin
    open p_product_curs for
      select w.id,
             w.barcode,
             w.product_name,
             w.quantity,
             w.exit_date,
             u.name,
             u.lastname,
             w.warehouse_name
        from khatia_warehouse_exchanges w
       inner join khatia_users u
          on u.id = w.operator_id
       where w.exit_date is not null
         and p_id = u.warehouse_id;
  end proc_get_exit_product;

  procedure proc_update_exit_product(p_barcode      varchar2,
                                     p_product_name varchar2,
                                     p_quantity     number,
                                     p_exit_date    varchar2,
                                     p_id           varchar2,
                                     p_unit         varchar2) is
  begin
    update khatia_warehouse_exchanges
       set barcode      = p_barcode,
           product_name = p_product_name,
           quantity     = p_quantity,
           exit_date    = p_exit_date,
           unit         = p_unit
     where id = p_id;
  end proc_update_exit_product;

  PROCEDURE proc_get_current_balance_forall(p_company_id   NUMBER,
                                            p_balance_curs OUT SYS_REFCURSOR) AS
  BEGIN
    OPEN p_balance_curs FOR
      WITH product_name_cte AS
       (SELECT w.barcode,
               MIN(w.product_name) KEEP(DENSE_RANK FIRST ORDER BY w.entry_date DESC NULLS LAST) AS product_name -- Choose product_name where entry_date is not null
          FROM khatia_warehouse_exchanges w
         WHERE w.entry_date IS NOT NULL
         GROUP BY w.barcode)
      SELECT w.barcode,
             pnc.product_name,
             SUM(CASE
                   WHEN w.entry_date IS NOT NULL AND w.exit_date IS NULL THEN
                    w.quantity
                   WHEN w.exit_date IS NOT NULL THEN
                    -w.quantity
                   ELSE
                    0
                 END) AS current_balance,
             w.warehouse_name
        FROM khatia_warehouse_exchanges w
       INNER JOIN khatia_users u
          ON w.operator_id = u.id
        LEFT JOIN product_name_cte pnc
          ON w.barcode = pnc.barcode
       WHERE p_company_id = u.company_id
       GROUP BY w.barcode, pnc.product_name, w.warehouse_name;
  END proc_get_current_balance_forall;

  PROCEDURE proc_get_current_balance(p_id           NUMBER,
                                     p_balance_curs OUT SYS_REFCURSOR) AS
  BEGIN
    OPEN p_balance_curs FOR
      WITH product_name_cte AS
       (SELECT w.barcode,
               MIN(w.product_name) KEEP(DENSE_RANK FIRST ORDER BY w.entry_date DESC NULLS LAST) AS product_name
          FROM khatia_warehouse_exchanges w
         WHERE w.entry_date IS NOT NULL
         GROUP BY w.barcode)
      SELECT w.barcode,
             pnc.product_name,
             u.name,
             u.lastname,
             w.warehouse_name,
             SUM(CASE
                   WHEN w.entry_date IS NOT NULL AND w.exit_date IS NULL THEN
                    w.quantity
                   WHEN w.exit_date IS NOT NULL THEN
                    -w.quantity
                   ELSE
                    0
                 END) AS current_balance
        FROM khatia_warehouse_exchanges w
       INNER JOIN khatia_users u
          ON u.id = w.operator_id
        LEFT JOIN product_name_cte pnc
          ON w.barcode = pnc.barcode
       WHERE p_id = u.warehouse_id
       GROUP BY w.barcode,
                pnc.product_name,
                u.name,
                u.lastname,
                w.warehouse_name;
  END proc_get_current_balance;

  procedure proc_add_warehouse(p_warehouse  varchar2,
                               p_company_id number,
                               p_address    varchar2) as
  begin
    insert into khatia_warehouse
      (warehouse, company_id, address)
    values
      (p_warehouse, p_company_id, p_address);
  end proc_add_warehouse;

  procedure proc_get_warehouses(p_company_id     number,
                                p_warehouse_curs out sys_refcursor) as
  begin
    open p_warehouse_curs for
      select w.id, w.warehouse, w.address
        from khatia_warehouse w
       where p_company_id = w.company_id;
  end proc_get_warehouses;

  procedure proc_update_warehouses(p_id        number,
                                   p_warehouse varchar2,
                                   p_address   varchar2) as
  begin
    update khatia_warehouse
       set warehouse = p_warehouse, address = p_address
     where id = p_id;
  end proc_update_warehouses;

  procedure proc_get_company_warehouse(p_id             number,
                                       p_warehouse_curs out sys_refcursor) as
  begin
    open p_warehouse_curs for
      select u.company_id, w.warehouse, u.warehouse_id
        from khatia_users u
        left join khatia_warehouse w
          on u.warehouse_id = w.id
       where p_id = u.id
         and (u.warehouse_id is null or u.warehouse_id = w.id);
  end proc_get_company_warehouse;
end pkg_warehouse_product_managment;
/


prompt Done
spool off
set define on
