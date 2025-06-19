use csa_project;
select * from dim_date;
select * from dim_hotels;
select * from dim_rooms;
select * from fact_aggregated_bookings;
select * from fact_bookings;

create table hotel as SELECT 
    fb.booking_id,
    fb.property_id,
    fb.booking_date,
    fb.check_in_date,
    fb.checkout_date,
    fb.no_guests,
    fb.room_category,
    fb.booking_platform,
    fb.ratings_given,
    fb.booking_status,
    fb.revenue_generated,
    fb.revenue_realized,

    dd.`mmm yy`,
    dd.`week no`,
    dd.day_type,

    dh.property_name,
    dh.category,
    dh.city,

    dr.room_class,

    fab.successful_bookings,
    fab.capacity

FROM fact_bookings fb

-- Join with dim_date (matching on formatted check-in date)
LEFT JOIN dim_date dd
    ON DATE_FORMAT(fb.check_in_date, '%d-%b-%y') = dd.date

-- Join with dim_hotels
LEFT JOIN dim_hotels dh
    ON fb.property_id = dh.property_id

-- Join with dim_rooms
LEFT JOIN dim_rooms dr
    ON fb.room_category = dr.room_id

-- Join with fact_aggregated_bookings
LEFT JOIN fact_aggregated_bookings fab
    ON fb.property_id = fab.property_id
    AND DATE_FORMAT(fb.check_in_date, '%d-%b-%y') = fab.check_in_date
    AND fb.room_category = fab.room_category;

select * from hotel;
create view rating_room_class as select room_class , round(avg(nullif(ratings_given,0)),2)  from hotel group by room_class ;
create view revenue_leak_room_class as select room_class , round(avg(revenue_generated-revenue_realized),2) as 'revenue_leakage'  from hotel group by room_class ;
alter view revenue_leak_season as select 	Season , round(avg(revenue_generated-revenue_realized),2) as 'revenue_leakage' from (select room_class,revenue_generated,revenue_realized,case when month(booking_date)=4 or month(booking_date)=5 then 'Summer' else 'Rainy' end as 'Season'  from hotel)g  group by g.Season; # so leakage is not dependent on season
create view revenue_leak_platform as select booking_platform , round(avg(revenue_generated-revenue_realized),2) as 'revenue_leakage'  from hotel group by booking_platform order by revenue_leakage desc ;
alter view top_5_booking as select booking_platform,room_class , season , count(booking_status) as 'booking_stat' from (select room_class,booking_platform,booking_status,case when month(booking_date)=4 or month(booking_date)=5 then 'Summer' else 'Rainy' end as 'Season'  from hotel where booking_status='Checked Out')g group by g.booking_platform,g.room_class,g.season order by count(booking_status) ;
create view revenue_leak_property as select city, property_name , round(avg(revenue_generated-revenue_realized),2) as 'revenue_leakage'  from hotel group by city , property_name;

alter view revenue_leak_monthly as select `mmm yy` , day_type, round(avg(revenue_generated-revenue_realized),2) as 'revenue_leakage'  from hotel group by `mmm yy`,day_type order by revenue_leakage desc ;

select * from revenue_leak_property;

select * from revenue_leak_platform;
select * from top_5_booking;
create view ADR as SELECT 
    property_name,
    room_category,
    `mmm yy` AS month,
    
    ROUND(SUM(revenue_realized) / NULLIF(count(*), 0), 2) AS ADR

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  property_name, room_category, `mmm yy`
ORDER BY property_name, month;

select * from adr;

alter view ADR as SELECT 
    property_name,
    room_category,
    `mmm yy` AS month,
    
    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  property_name, room_category, `mmm yy`
ORDER BY property_name, month;

create view Revpar as
SELECT 
    property_name,
    room_category,
    `mmm yy` AS month,
    
    ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) AS RevPar

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  property_name, room_category, `mmm yy`
ORDER BY property_name, month;

create view occupancy_percent as
SELECT 
    property_name,
    room_category,
    `mmm yy` AS month,
	ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) AS OccupancyPercent

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  property_name, room_category, `mmm yy`
ORDER BY property_name, month,OccupancyPercent desc;

CREATE view 3_kpi_book_platform as 
SELECT 
    booking_platform,
    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR,
	ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) AS RevPar,
    ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) AS OccupancyPercent
FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  booking_platform
ORDER BY  ADR,RevPar,OccupancyPercent desc;

SELECT 
    room_class,
    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR,
	ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) AS RevPar,
    ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) AS OccupancyPercent
FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY  room_class
ORDER BY  ADR,RevPar,OccupancyPercent desc; # Scenario	Insight High ADR, low occupancy	Premium rooms likely overpriced Low ADR, high occupancy	Underpriced; revenue opportunity missed , balanced ADR & occupancy	Pricing aligns with market demand
# In Power BI: Create a scatter plot:
#X-axis: ADR
#Y-axis: Occupancy Percent
#Legend: room_category
#Play Axis or Slicer: month

create view 3_kpi_monthly_Wise as 
SELECT 
    `mmm yy` AS month,
    property_id,
    property_name,

    SUM(revenue_realized) AS total_revenue,
    SUM(successful_bookings) AS rooms_sold,
    SUM(capacity) AS rooms_available,

    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR,
    ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) AS RevPAR,
    ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) AS occupancy_percent

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY `mmm yy`, property_id, property_name
ORDER BY property_id, month;

create view rating_vs_adr as
SELECT 
    city,
    property_name,
    room_category,
    round(AVG(ratings_given),2) AS avg_guest_rating,

    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR

FROM hotel
WHERE booking_status = 'Checked Out'
  AND ratings_given IS NOT NULL
  AND ratings_given > 0
GROUP BY city, property_name, room_category
ORDER BY avg_guest_rating DESC;

select property_name,count(*) from hotel where booking_status='Cancelled' group by property_name;
create view cancel_rate_all_metric as select city,property_name,day_type , booking_platform , round(sum(cancelled_val)/count(*) *100,2) as cancel_rate from (select city,property_name,day_type,case when booking_status='Cancelled' then 1 else 0  end as cancelled_val,booking_platform from hotel  WHERE booking_status IN ('Cancelled', 'Checked Out'))g group by city,property_name,day_type,booking_platform;
select * from hotel;
alter view underperform_hotels as
SELECT 
    city,
    property_name,
    `mmm yy` AS `month`,
    ROUND(SUM(revenue_realized) / NULLIF(SUM(successful_bookings), 0), 2) AS ADR,
    ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) AS RevPAR,
    ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) AS OccupancyPercent,

    -- Alert Flags
    CASE 
        WHEN ROUND(SUM(revenue_realized) / NULLIF(SUM(capacity), 0), 2) < 150 THEN 'Low RevPAR'
        ELSE 'OK'
    END AS RevPAR_Status,

    CASE 
        WHEN ROUND((SUM(successful_bookings) / NULLIF(SUM(capacity), 0)) * 100, 2) < 60 THEN 'Low Occupancy'
        ELSE 'OK'
    END AS Occupancy_Status
FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY city,property_name, `month`

HAVING RevPAR_Status = 'Low RevPAR' OR Occupancy_Status = 'Low Occupancy'
ORDER BY month, property_name;

create view avg_guest_revenue as SELECT 
    property_id,
    property_name,
    room_category,
    `mmm yy` AS month,

    -- Average number of guests per booking
    ROUND(AVG(no_guests)) AS avg_guests_per_booking,

    -- Revenue per guest
    ROUND(SUM(revenue_realized) / NULLIF(SUM(no_guests), 0), 2) AS revenue_per_guest

FROM hotel
WHERE booking_status = 'Checked Out'
GROUP BY property_id, property_name, room_category, `mmm yy`
ORDER BY avg_guests_per_booking DESC; # <60 = low occupancy

alter view 3_final_kpi as 
SELECT 
    booking_platform,
    `mmm yy`,
    property_name,
    city,
    room_category,
    ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) / 
          NULLIF(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END), 0), 2) AS ADR,
    
    ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) / 
          NULLIF(SUM(capacity), 0), 2) AS RevPar,

    ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) / 
          NULLIF(SUM(capacity), 0) * 100, 2) AS OccupancyPercent,

    ROUND(SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) / 
          COUNT(*) * 100, 2) AS CancellationRate

FROM hotel
GROUP BY booking_platform, `mmm yy`, property_name, city, room_category
ORDER BY ADR, RevPar, OccupancyPercent DESC;

SELECT 
    booking_platform,
    room_category,
    COUNT(*) AS total_bookings,
    ROUND(SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS cancellation_rate,
    ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) / 
          NULLIF(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END), 0), 2) AS adr,
    ROUND(SUM(revenue_realized), 2) AS total_revenue
FROM hotel
GROUP BY booking_platform, room_category
ORDER BY total_bookings DESC;

