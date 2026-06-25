-- PostgreSQL Optimization Demo
-- Use EXPLAIN or EXPLAIN ANALYZE before each query to compare execution plans.

-- ============================================================
-- 1. Non-optimized query
-- ============================================================


-- найновіше замовлення в найпопулярнішій категорії
select 
	(
		-- загальна кількість замовлень найкращої категорії
		select count(*)
		from (
		-- всі активні замовлення, ордер + продукт категорія
			select o.order_id, p.product_category 
			from opt_orders o
			join opt_products p on o.product_id = p.product_id
			join opt_clients c on o.client_id = c.id 
			where c.status = 'active'
		) as cnt
		where cnt.product_category = (
			-- найкраща категорія
			select cnt.product_category
			from (
				select p.product_category, count(*) as cat_cnt
				from opt_orders o
				join opt_products p on o.product_id = p.product_id
				join opt_clients c on o.client_id  = c.id 
				where c.status = 'active'
				group by p.product_category
				order by cat_cnt desc
				limit 1
			) as top_cat
		) 
	) as top_ctgry_total_ord,
	(
	-- номер найновішого замовлення
		select concat('Order #', order_id, ' on ', order_date)
		from (
			select o.order_id, o.order_date, p.product_category
			from opt_orders o
			join opt_products p on o.order_id  = p.product_id 
			join opt_clients c on o.client_id  = c.id
			where c.status = 'active'
		) as ltst_ord
		-- лише найпопулярніша категорія
		where ltst_ord.product_category = (
			select product_category
			from (
				select p.product_category, count(*) as cat_cnt
				from opt_orders o
				join opt_products p on o.order_id  = p.product_id 
				join opt_clients c on o.client_id  = c.id
				where c.status = 'active'
				group by p.product_category
				order by cat_cnt desc
				limit 1
			) as top_cat2
		)
		-- найновіше і тільки одне
		order by order_date desc
		limit 1
	) as ltst_ord_in_tp_ctg
	

-- написати свій оптимізоні

