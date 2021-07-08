set search_path to bookings

--1 В каких городах больше одного аэропорта?
select city, count(airport_code)
from airports
group by city 
having count(airport_code) > 1

--2 В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
select q.city, a.airport_name 
from (
	select distinct departure_airport as city
	from flights f
	join (select aircraft_code
		from aircrafts
		order by range desc limit 1) a 
		on f.aircraft_code = a.aircraft_code
) q
join airports a on a.airport_code = q.city


select distinct departure_airport as city, ai.airport_name
from flights f
join (select aircraft_code
	from aircrafts
	order by range desc limit 1) a 
	on f.aircraft_code = a.aircraft_code
join airports ai on ai.airport_code = f.departure_airport

--3 Вывести 10 рейсов с максимальным временем задержки вылета
select flight_id, flight_no, actual_departure - scheduled_departure as delta
from flights
where actual_departure - scheduled_departure is not null
order by delta desc
limit 10

--4 Были ли брони, по которым не были получены посадочные талоны?
select *
from tickets t
left join boarding_passes bp on t.ticket_no = bp.ticket_no
where bp.ticket_no is null

--5 
/* Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных 
пассажиров из каждого аэропорта на каждый день. Т.е. в этом столбце должна отражаться 
накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более 
ранних рейсах за день. */

with cte as (
	select f.flight_id, f.departure_airport, f.status, f.scheduled_departure, s.seats, tf.book_seats
	from flights f
	left join (
		select flight_id, count(ticket_no) as book_seats
		from ticket_flights
		group by flight_id) as tf
		on tf.flight_id = f.flight_id
	left join (
		select aircraft_code, count(seat_no) as seats
		from seats
		group by aircraft_code) as s
		on s.aircraft_code = f.aircraft_code
)
select *,
	(seats - book_seats) as free_seats, 
	round(((seats - book_seats)::numeric/seats::numeric)*100, 1) as percent,
	sum(book_seats) over(partition by departure_airport, date_trunc('day', scheduled_departure) order by scheduled_departure)
from cte
where status ilike 'arrived' or status ilike 'departed'


--6 Найдите процентное соотношение перелетов по типам самолетов от общего количества.
select f.aircraft_code, f.count, round(f.percent*100, 2) as percent_to_total
from (
	select aircraft_code, count(flight_id), count(flight_id)/sum(count(flight_id)) over() as percent
	from flights
	group by aircraft_code
) f
order by percent_to_total desc

--7 Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
with tf_1 as (
	select flight_id, fare_conditions, min(amount)
	from ticket_flights
	where fare_conditions ilike 'business'
	group by flight_id, fare_conditions
)
select *
from tf_1
left join (
	select flight_id, fare_conditions, max(amount)
	from ticket_flights
	where fare_conditions ilike 'economy'
	group by flight_id, fare_conditions
) tf_2 on tf_2.flight_id = tf_1.flight_id
where tf_1.min <= tf_2.max

--8 Между какими городами нет прямых рейсов?
create view all_flights as
select distinct a1.city as x, a2.city as y
from flights f
join airports a1 on a1.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport

select distinct q1.city as x, q2.city as y
from airports q1
cross join (select distinct city
			from airports) q2
where q1.city != q2.city			
except
select *
from all_flights
