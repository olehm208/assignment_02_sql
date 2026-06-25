-- PostgreSQL Optimization Demo
-- Use EXPLAIN or EXPLAIN ANALYZE before each query to compare execution plans.

-- ============================================================
-- 1. Non-optimized query
-- ============================================================


-- найновіше замовлення в найпопулярнішій категорії

drop index idx_client_status;
drop index idx_orders_client_id;
drop index idx_orders_product_id;
drop index idx_products_category;
drop index idx_orders_date_id;

explain analyze
select 
    (
		--загальна кількість оредерів в найкращих категоріях
        select count(*)
        from (
            select o.order_id, p.product_category
            from opt_orders o
            join opt_products p on o.product_id = p.product_id
            join opt_clients c on o.client_id = c.id
            where c.status = 'active'
        ) as ao
        where ao.product_category = (
        --найпопулярніша категорія
            select tc.product_category
            from (
                select p.product_category, count(*) as cat_cnt
                from opt_orders o
                join opt_products p on o.product_id = p.product_id
                join opt_clients c on o.client_id = c.id
                where c.status = 'active'
                group by p.product_category
                order by cat_cnt desc, p.product_category asc
                limit 1
            ) as tc
        )
    ) as top_category_total_orders,
    (
		--останнє замовлення в найкращої категорії
        select concat('order #', lo.order_id, ' on ', lo.order_date)
        from (
            select o.order_id, o.order_date, p.product_category
            from opt_orders o
            join opt_products p on o.product_id = p.product_id
            join opt_clients c on o.client_id = c.id
            where c.status = 'active'
        ) as lo
        where lo.product_category in (
            select s.product_category
            from (
                select p.product_category, o.order_date
                from opt_orders o
                join opt_products p on o.product_id = p.product_id
                join opt_clients c on o.client_id = c.id
                where c.status = 'active'
                  and p.product_category = (
                      select p1.product_category
                      from (
                      --останнє замовлення в найкращої категорії
                          select p.product_category, count(*) as cat_cnt
                          from opt_orders o
                          join opt_products p on o.product_id = p.product_id
                          join opt_clients c on o.client_id = c.id
                          where c.status = 'active'
                          group by p.product_category
                          order by cat_cnt desc, p.product_category asc
                          limit 1
                      ) as p1
                  )
                order by o.order_date desc, o.order_id asc
            ) as s
        )
        order by lo.order_date desc, lo.order_id asc
        limit 1
    ) as latest_order_in_top_category;
	
-- написати свій оптимізон

create index idx_client_status on opt_clients(status);
create index idx_orders_client_id on opt_orders(client_id);
create index idx_orders_product_id on opt_orders(product_id);
create index idx_products_category on opt_products(product_id, product_category);
create index idx_orders_date_id on opt_orders(order_date desc, order_id asc);
	
with TopCategory as (
explain analyze
    select
        products.product_category,
        count(*) as category_count
    from opt_orders orders
    join opt_products products on orders.product_id = products.product_id
    join opt_clients clients on orders.client_id = clients.id
    where clients.status = 'active'
    group by products.product_category
    order by category_count desc, products.product_category asc
    limit 1
),
LatestOrder as (
select orders.order_id, orders.order_date
    from opt_orders orders
    join opt_products products on orders.product_id = products.product_id
    join opt_clients clients on orders.client_id = clients.id
    where clients.status = 'active'
      and products.product_category = (select product_category from TopCategory)
    order by orders.order_date desc, orders.order_id asc
    limit 1
)
select
    (select category_count from TopCategory) as top_category_total_orders,
    (select concat('Order #', order_id, ' on ', order_date) from LatestOrder) as latest_order_in_top_category;


-- unoptimized: 900ms
-- optimized: 153ms
--The non-optimized query recalculates the same joined, filtered, 
-- and aggregated dataset multiple times across repetitive, deeply nested subqueries.
-- The optimized query:
-- Filters and joins active orders once for the single top category and its total count in TopCategory
-- Reuses TopCategory for LatestOrder
-- Uses Limit 1 to not overdo
-- uses indexes on filtered and joined indexes: 
--opt_clients(status);
--opt_orders(client_id);
--opt_orders(product_id);
--opt_products(product_id, product_category);
--opt_orders(order_date desc, order_id asc);