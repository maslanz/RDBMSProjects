create database airline_relational_db
use airline_relational_db

/*TABLES*/
create table FLIGHT (
	Flight_number varchar(8),
	Airline varchar(32) not null,
	Weekdays varchar(16),
	primary key(Flight_number)
)

create table AIRPORT (
	Airport_code varchar(3),
	Name varchar(32) not null,
	City varchar(16) not null,
	State varchar(16) not null,
	primary key(Airport_code)
)

create table AIRPLANE_TYPE (
	Airplane_type_name varchar(16),
	Max_seats int not null,
	Company varchar(16) not null,
	primary key(Airplane_type_name)
)

create table FARE (
	Flight_number varchar(8),
	Fare_code int,
	Amount int not null,
	Restrictions bit not null,
	Baggage_weight int not null --added later
	primary key(Flight_number, Fare_code),
	foreign key(Flight_number) references FLIGHT(Flight_number) on delete cascade on update cascade
)

create table AIRPLANE (
	Airplane_id int,
	Total_number_of_seats int not null,
	Airplane_type varchar(16) not null,
	primary key(Airplane_id),
	foreign key(Airplane_type) references AIRPLANE_TYPE(Airplane_type_name) on delete cascade on update cascade
)

create table CAN_LAND (
	Airplane_type_name varchar(16),
	Airport_code varchar(3),
	primary key(Airplane_type_name, Airport_code),
	foreign key(Airplane_type_name) references AIRPLANE_TYPE(Airplane_type_name) on delete cascade on update cascade,
	foreign key(Airport_code) references AIRPORT(Airport_code) on delete cascade on update cascade
)

create table FLIGHT_LEG (
	Flight_number varchar(8),
	Leg_number int,
	Departure_airport_code varchar(3) not null,
	Scheduled_departure_time datetime not null,
	Arrival_airport_code varchar(3) not null,
	Scheduled_arrival_time datetime not null,
	primary key(Flight_number, Leg_number),
	foreign key(Flight_number) references FLIGHT(Flight_number) on delete no action on update no action,
	foreign key(Departure_airport_code) references AIRPORT(Airport_code) on delete no action on update no action,
	foreign key(Arrival_airport_code) references AIRPORT(Airport_code) on delete no action on update no action
)

create table LEG_INSTANCE (
	Flight_number varchar(8),
	Leg_number int,
	Date date,
	Number_of_available_seats int not null,
	Airplane_id int not null,
	Departure_airport_code varchar(3) not null,
	Departure_time time(7) not null,
	Arrival_airport_code varchar(3) not null,
	Arrival_time time(7) not null,
	primary key(Flight_number, Leg_number, Date),
	foreign key(Flight_number, Leg_number) references FLIGHT_LEG(Flight_number, Leg_number) on delete no action on update no action,
	foreign key(Airplane_id) references AIRPLANE(Airplane_id) on delete no action on update no action,
	foreign key(Departure_airport_code) references AIRPORT(Airport_code) on delete no action on update no action,
	foreign key(Arrival_airport_code) references AIRPORT(Airport_code) on delete no action on update no action
)

create table SEAT_RESERVATION (
	Flight_number varchar(8),
	Leg_number int,
	Date date,
	Seat_number varchar(3),
	Customer_name varchar(32) not null,
	Customer_phone varchar(16) not null,
	primary key(Flight_number, Leg_number, Date, Seat_number),
	foreign key(Flight_number, Leg_number, Date) references LEG_INSTANCE(Flight_number, Leg_number, Date) on delete cascade on update cascade
)

/*CHECK CONSTRAINTS*/
alter table FLIGHT add constraint check_flight_weekdays
check (weekdays in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'));

alter table AIRPLANE_TYPE add constraint check_airplane_type_max_seats
check (max_seats<=850);

alter table LEG_INSTANCE add constraint check_leg_instance_time
check (Departure_time!=Arrival_time);

alter table FLIGHT_LEG add constraint check_flight_leg_time
check (Scheduled_departure_time!=Scheduled_arrival_time);

alter table FLIGHT_LEG add constraint check_flight_leg_code
check (Departure_airport_code!=Arrival_airport_code);

alter table FARE add constraint check_amount
check (amount>=0);

/*ASSERTIONS*/
create trigger seat_ranking1 on	AIRPLANE
after insert
as begin
declare @Total_number_of_seats int, @Airplane_type varchar(16), @Max_seats int
select @Total_number_of_seats=Total_number_of_seats, @Airplane_type=Airplane_type, @Max_seats=Max_seats
from AIRPLANE_TYPE inner join inserted on AIRPLANE_TYPE.Airplane_type_name=inserted.Airplane_type
if @Total_number_of_seats>@Max_seats
begin
rollback transaction
raiserror('Total_number_of_seats cannot be greater than Max_seats',16,1)
end
end

create trigger seat_ranking2 on	LEG_INSTANCE
after insert
as begin
declare @Number_of_available_seats int, @Airplane_id int, @Total_number_of_seats int
select @Number_of_available_seats=Number_of_available_seats, @Total_number_of_seats=Total_number_of_seats
from AIRPLANE inner join inserted on AIRPLANE.Airplane_id=inserted.Airplane_id
if @Number_of_available_seats>@Total_number_of_seats
begin
rollback transaction
raiserror('Number_of_available_seats cannot be greater than Total_number_of_seats',16,1)
end
end

/*TRIGGERS*/
create trigger decrement_seat on SEAT_RESERVATION
after insert
as begin
declare @Flight_number varchar(8), @Leg_number int, @Date date
select @Flight_number=Flight_number, @Leg_number=Leg_number, @Date=Date from inserted
update LEG_INSTANCE set Number_of_available_seats=Number_of_available_seats-1
where LEG_INSTANCE.Flight_number=@Flight_number and LEG_INSTANCE.Leg_number=@Leg_number and LEG_INSTANCE.Date=@Date
end

create trigger inserting_company_and_type on AIRPLANE_TYPE
for insert
as begin
declare @Airplane_type_name varchar(16)
select @Airplane_type_name=Airplane_type_name from inserted
if @Airplane_type_name like 'Boeing%'
begin
update AIRPLANE_TYPE set Company='Boeing'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Airbus%'
begin
update AIRPLANE_TYPE set Company='Airbus'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Antonov%'
begin
update AIRPLANE_TYPE set Company='Antonov'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Tupolev%'
begin
update AIRPLANE_TYPE set Company='Tupolev'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Embraer%'
begin
update AIRPLANE_TYPE set Company='Embraer'
where Airplane_type_name=@Airplane_type_name
end
end

create trigger total_amount on FARE
after insert
as begin
declare @Flight_number varchar(8), @Fare_code int, @Baggage_weight int, @Restrictions bit
select @Flight_number=Flight_number, @Fare_code=Fare_code, @Baggage_weight=Baggage_weight, @Restrictions=Restrictions from inserted
if @Restrictions=1 and @Baggage_weight>20
begin
update FARE set Amount=Amount+(@Baggage_weight-20)*8
where Flight_number=@Flight_number and @Fare_code=Fare_code 
end
end

/*DATA VALUES*/
/*for AIRPORT table*/
insert into AIRPORT values ('IST','Atatürk Airport','Istanbul','Turkey')
insert into AIRPORT values ('ADB','Adnan Menderes Airport','Izmir','Turkey')
insert into AIRPORT values ('ATL','H. Jackson Atlanta Airport','Atlanta/Georgia','United Sates')
insert into AIRPORT values ('PEK','Beijing Capital Airport','Beijing','China')
insert into AIRPORT values ('DXB','Dubai International Airport','Dubai','UAE')
insert into AIRPORT values ('CDG','Charles de Gaulle Airport','Paris','France')
insert into AIRPORT values ('LHR','Heathrow Airport','London','United Kingdom')
insert into AIRPORT values ('FRA','Frankfurt Airport','Frankfurt','Germany')
insert into AIRPORT values ('LAX','Los Angeles Airport','LA/California','United States')
insert into AIRPORT values ('AMS','Amsterdam Airport Schiphol','Amsterdam','The Netherlands')
insert into AIRPORT values ('ICN','Seoul Incheon Airport','Seoul','South Korea')
insert into AIRPORT values ('MAD','Madrid Barajas Airport','Madrid','Spain')
insert into AIRPORT values ('DEL','Indira Gandhi Airport','Delhi','India')
insert into AIRPORT values ('HND','Tokyo International Airport','Tokyo','Japan')
insert into AIRPORT values ('CIA','Ciampino Airport','Roma','Italy')

/*for FLIGHT table*/
insert into FLIGHT values ('PC1864','Pegasus Airlines','Sunday') 
insert into FLIGHT values ('TK2969','Turkish Airlines','Friday') 
insert into FLIGHT values ('UA844','United Airlines','Thursday')
insert into FLIGHT values ('AF5321','Air France','Wednesday')
insert into FLIGHT values ('AZ608','Alitalia','Wednesday')
insert into FLIGHT values ('AI636','Air India','Saturday') --
insert into FLIGHT values ('QR517','Qatar Airways','Tuesday')
insert into FLIGHT values ('EY58','Etihad Airways','Tuesday') --
insert into FLIGHT values ('NH74','All Nippon Airways','Monday')
insert into FLIGHT values ('KE19','Korean Airways','Saturday')
insert into FLIGHT values ('EK27','Emirates','Sunday') --
insert into FLIGHT values ('AA1379','American Airlines','Monday') --
insert into FLIGHT values ('BA1342','British Airways','Thursday')
insert into FLIGHT values ('UX92','Air Europa','Friday') 
insert into FLIGHT values ('CZ6715','China Southern Airlines','Saturday')

/*for AIRPLANE_TYPE table*/
insert into AIRPLANE_TYPE values ('Airbus-A380',616,' ')
insert into AIRPLANE_TYPE values ('Boeing-747',469,' ')
insert into AIRPLANE_TYPE values ('Boeing-737',495,' ')
insert into AIRPLANE_TYPE values ('Tupolev-204',441,' ')
insert into AIRPLANE_TYPE values ('Embraer-190',467,' ')
insert into AIRPLANE_TYPE values ('Boeing-777',752,' ')
insert into AIRPLANE_TYPE values ('Antonov-72',454,' ')
insert into AIRPLANE_TYPE values ('Embraer-170',398,' ')
insert into AIRPLANE_TYPE values ('Airbus-A320',502,' ')
insert into AIRPLANE_TYPE values ('Airbus-A320s',557,' ')
insert into AIRPLANE_TYPE values ('Airbus-A380s',703,' ')
insert into AIRPLANE_TYPE values ('Tupolev-154',413,' ')
insert into AIRPLANE_TYPE values ('Embraer-195',499,' ')
insert into AIRPLANE_TYPE values ('Boeing-757',558,' ')
insert into AIRPLANE_TYPE values ('Boeing-767',633,' ')

/*for AIRPLANE table*/
insert into AIRPLANE values (101,362,'Airbus-A320')
insert into AIRPLANE values (102,379,'Airbus-A320s')
insert into AIRPLANE values (103,481,'Airbus-A380')
insert into AIRPLANE values (104,503,'Airbus-A380s')
insert into AIRPLANE values (105,312,'Antonov-72')
insert into AIRPLANE values (106,364,'Boeing-737')
insert into AIRPLANE values (107,366,'Boeing-747')
insert into AIRPLANE values (108,432,'Boeing-757')
insert into AIRPLANE values (109,501,'Boeing-767')
insert into AIRPLANE values (201,541,'Boeing-777')
insert into AIRPLANE values (202,289,'Embraer-170')
insert into AIRPLANE values (203,334,'Embraer-190')
insert into AIRPLANE values (204,375,'Embraer-195')
insert into AIRPLANE values (205,277,'Tupolev-154')
insert into AIRPLANE values (206,309,'Tupolev-204')

/*for CAN_LAND table*/
insert into CAN_LAND values ('Airbus-A380s','ATL')
insert into CAN_LAND values ('Airbus-A320s','PEK')
insert into CAN_LAND values ('Tupolev-204','DEL')
insert into CAN_LAND values ('Boeing-767','FRA')
insert into CAN_LAND values ('Boeing-737','ADB')
insert into CAN_LAND values ('Airbus-A380s','LAX')
insert into CAN_LAND values ('Boeing-757','CDG')
insert into CAN_LAND values ('Embraer-195','LHR')
insert into CAN_LAND values ('Boeing-777','ATL')
insert into CAN_LAND values ('Boeing-747','IST')
insert into CAN_LAND values ('Airbus-A320s','HND')
insert into CAN_LAND values ('Embraer-195','LAX')
insert into CAN_LAND values ('Boeing-777','DXB')
insert into CAN_LAND values ('Tupolev-204','MAD')
insert into CAN_LAND values ('Boeing-747','CDG')
insert into CAN_LAND values ('Boeing-737','CIA')
insert into CAN_LAND values ('Airbus-A320s','ICN')
insert into CAN_LAND values ('Boeing-767','AMS')

/*for FARE table*/
insert into FARE values ('AA1379',1001,175,0,25)
insert into FARE values ('AF5321',1002,80,1,17)
insert into FARE values ('AI636',1003,110,1,21)
insert into FARE values ('AZ608',1004,65,1,12)
insert into FARE values ('BA1342',1005,90,1,14)
insert into FARE values ('CZ6715',1006,130,1,26)
insert into FARE values ('EK27',1007,210,0,19)
insert into FARE values ('EY58',1008,155,1,23)
insert into FARE values ('KE19',1009,45,1,15)
insert into FARE values ('NH74',1010,70,1,12)
insert into FARE values ('PC1864',1011,30,1,22)
insert into FARE values ('QR517',1012,235,0,13)
insert into FARE values ('TK2969',1013,90,1,24)
insert into FARE values ('UA844',1014,180,1,20)
insert into FARE values ('UX92',1015,60,1,21)

/*for FLIGHT_LEG table*/
insert into FLIGHT_LEG values ('PC1864',1,'ADB','12/17/2017 11:30','IST','12/17/2017 12:45')
insert into FLIGHT_LEG values ('AF5321',1,'CDG','12/13/2017 20:45','FRA','12/13/2017 22:00')
insert into FLIGHT_LEG values ('NH74',1,'HND','12/11/2017 13:55','ICN','12/11/2017 16:35')
insert into FLIGHT_LEG values ('TK2969',1,'IST','12/15/2017 14:50','AMS','12/15/2017 16:45')
insert into FLIGHT_LEG values ('BA1342',1,'LHR','12/14/2017 15:10','MAD','12/14/2017 17:35')
insert into FLIGHT_LEG values ('CZ6715',1,'DEL','12/16/2017 07:10','PEK','12/16/2017 12:55')
insert into FLIGHT_LEG values ('AZ608',1,'CIA','12/13/2017 11:10','LHR','12/13/2017 14:00')
insert into FLIGHT_LEG values ('UA844',1,'ATL','12/14/2017 08:20','LAX','12/14/2017 13:35')
insert into FLIGHT_LEG values ('KE19',1,'ICN','12/16/2017 09:20','PEK','12/16/2017 10:35')
insert into FLIGHT_LEG values ('UX92',1,'AMS','12/15/2017 12:30','FRA','12/15/2017 13:35')
insert into FLIGHT_LEG values ('QR517',1,'CDG','12/12/2017 11:30','IST','12/12/2017 15:00')
insert into FLIGHT_LEG values ('PC1864',2,'IST','12/17/2017 14:00','AMS','12/17/2017 17:45')
insert into FLIGHT_LEG values ('TK2969',2,'AMS','12/15/2017 19:00','LAX','12/16/2017 06:00')
insert into FLIGHT_LEG values ('KE19',2,'PEK','12/16/2017 13:10','HND','12/16/2017 17:30')
insert into FLIGHT_LEG values ('UX92',2,'FRA','12/15/2017 15:00','IST','12/15/2017 18:00')
insert into FLIGHT_LEG values ('AZ608',2,'LHR','12/13/2017 16:30','ATL','12/14/2017 02:05')
insert into FLIGHT_LEG values ('QR517',2,'IST','12/12/2017 16:30','DXB','12/12/2017 22:45')


/*for LEG_INSTANCE table*/
insert into LEG_INSTANCE values ('PC1864',1,'12/17/2017',210,106,'ADB','11:32','IST','12:55')
insert into LEG_INSTANCE values ('AF5321',1,'12/13/2017',335,108,'CDG','20:45','FRA','22:00')
insert into LEG_INSTANCE values ('NH74',1,'12/11/2017',303,102,'HND','13:55','ICN','16:35')
insert into LEG_INSTANCE values ('TK2969',1,'12/15/2017',280,107,'IST','15:05','AMS','17:10')
insert into LEG_INSTANCE values ('BA1342',1,'12/14/2017',252,204,'LHR','15:15','MAD','17:40')
insert into LEG_INSTANCE values ('CZ6715',1,'12/16/2017',214,206,'DEL','07:20','PEK','13:05')
insert into LEG_INSTANCE values ('AZ608',1,'12/13/2017',263,106,'CIA','11:10','LHR','14:00')
insert into LEG_INSTANCE values ('UA844',1,'12/14/2017',381,104,'ATL','08:45','LAX','14:00')
insert into LEG_INSTANCE values ('KE19',1,'12/16/2017',223,102,'ICN','09:30','PEK','10:45')
insert into LEG_INSTANCE values ('UX92',1,'12/15/2017',365,109,'AMS','12:30','FRA','13:35')
insert into LEG_INSTANCE values ('QR517',1,'12/12/2017',267,107,'CDG','11:35','IST','15:10')
insert into LEG_INSTANCE values ('PC1864',2,'12/17/2017',210,106,'IST','16:30','AMS','20:15')
insert into LEG_INSTANCE values ('TK2969',2,'12/15/2017',280,107,'AMS','19:00','LAX','06:00')
insert into LEG_INSTANCE values ('KE19',2,'12/16/2017',223,102,'PEK','14:40','HND','19:00')
insert into LEG_INSTANCE values ('UX92',2,'12/15/2017',365,109,'FRA','15:15','IST','18:00')
insert into LEG_INSTANCE values ('AZ608',2,'12/13/2017',263,106,'LHR','17:00','ATL','02:40')
insert into LEG_INSTANCE values ('QR517',2,'12/12/2017',267,107,'IST','11:35','ADB','13:00')

/*for SEAT_RESERVATION table*/
insert into SEAT_RESERVATION values ('PC1864',1,'12/17/2017','12F','Kemalettin Tuðcu','05053265414')
insert into SEAT_RESERVATION values ('PC1864',1,'12/17/2017','6B','Cemal Tonga','05366874125')
insert into SEAT_RESERVATION values ('AF5321',1,'12/13/2017','25C','Tony Parker','565413322')
insert into SEAT_RESERVATION values ('AF5321',1,'12/13/2017','14B','Antoine Griezmann','656565889')
insert into SEAT_RESERVATION values ('NH74',1,'12/11/2017','11A','Uchiha Itachi','6468641351')
insert into SEAT_RESERVATION values ('NH74',1,'12/11/2017','12A','Hattori Hanzo','8742123')
insert into SEAT_RESERVATION values ('TK2969',1,'12/15/2017','21D','Serdar Ortaç','0588123654')
insert into SEAT_RESERVATION values ('TK2969',1,'12/15/2017','19B','Aleyna Tilki','612354798')
insert into SEAT_RESERVATION values ('BA1342',1,'12/14/2017','13A','Sir Alex Ferguson','7856464651')
insert into SEAT_RESERVATION values ('BA1342',1,'12/14/2017','11F','Andy Murray','31351545')
insert into SEAT_RESERVATION values ('CZ6715',1,'12/16/2017','14E','Yao Ming','312351541')
insert into SEAT_RESERVATION values ('CZ6715',1,'12/16/2017','13B','Lucy Liu','132135465')
insert into SEAT_RESERVATION values ('AZ608',1,'12/13/2017','11D','Francesco Totti','32432434')
insert into SEAT_RESERVATION values ('AZ608',1,'12/13/2017','8E','Alessandra Ambrosio','123124556')
insert into SEAT_RESERVATION values ('UA844',1,'12/14/2017','1A','Margot Robbie','12412556')
insert into SEAT_RESERVATION values ('UA844',1,'12/14/2017','8D','Gal Gadot','124555624')
insert into SEAT_RESERVATION values ('KE19',1,'12/16/2017','15C','Park Ji-Sung','12354325')
insert into SEAT_RESERVATION values ('KE19',1,'12/16/2017','14A','Son Heung-Min','124325569')
insert into SEAT_RESERVATION values ('UX92',1,'12/15/2017','18B','Dirk Kuyt','564646545')
insert into SEAT_RESERVATION values ('UX92',1,'12/15/2017','11D','Ryan Babel','66564512')
insert into SEAT_RESERVATION values ('QR517',1,'12/12/2017','18C','Didier Deschamps','263465312')
insert into SEAT_RESERVATION values ('QR517',1,'12/12/2017','31A','Emmanuelle Mimieux','134465602')
insert into SEAT_RESERVATION values ('PC1864',2,'12/17/2017','27F','Kemalettin Tuðcu','05053265414')
insert into SEAT_RESERVATION values ('PC1864',2,'12/17/2017','15C','Sabahattin Ali','05411223545')
insert into SEAT_RESERVATION values ('TK2969',2,'12/15/2017','14B','Serdar Ortaç','0588123654')
insert into SEAT_RESERVATION values ('TK2969',2,'12/15/2017','24E','Nazým Hikmet Ran','0541616656')
insert into SEAT_RESERVATION values ('KE19',2,'12/16/2017','13A','Park Ji-Sung','12354325')
insert into SEAT_RESERVATION values ('KE19',2,'12/16/2017','11F','Bae Doona','34554646')
insert into SEAT_RESERVATION values ('UX92',2,'12/15/2017','11B','Dirk Kuyt','564646545')
insert into SEAT_RESERVATION values ('UX92',2,'12/15/2017','30C','Robin van Persie','13215647')
insert into SEAT_RESERVATION values ('AZ608',2,'12/13/2017','14E','Alessandra Ambrosio','123124556')
insert into SEAT_RESERVATION values ('AZ608',2,'12/13/2017','10A','Pierluigi Collina','26515615')
insert into SEAT_RESERVATION values ('QR517',2,'12/12/2017','22B','Emmanuelle Mimieux','134465602')
insert into SEAT_RESERVATION values ('QR517',2,'12/12/2017','14F','Nasser Al-Khelaifi','134465602')

/*SQL STATEMENTS*/
insert into AIRPORT values ('VKO','Vnukova Airport','St. Petersburg','Russia')
update AIRPORT set City='Moscow' where Airport_code='VKO'
delete from AIRPORT where Airport_code='VKO'

insert into FLIGHT values ('SU1860','Aeroflot','Wednesday')
update FLIGHT set Weekdays='Friday' where Flight_number='SU1860'
delete from FLIGHT where Flight_number='SU1860'

insert into AIRPLANE_TYPE values ('Tupolev-244','532',' ')
update AIRPLANE_TYPE set Max_seats='510' where Airplane_type_name='Tupolev-244'
delete from AIRPLANE_TYPE where Airplane_type_name='Tupolev-244'

select Company, Airplane_type, Total_number_of_seats
from AIRPLANE, AIRPLANE_TYPE
where AIRPLANE.Airplane_type=AIRPLANE_TYPE.Airplane_type_name
and AIRPLANE.Total_number_of_seats>450

select FLIGHT.Flight_number, Airline, Amount, Weekdays
from FARE, FLIGHT
where FARE.Flight_number=FLIGHT.Flight_number 
and FLIGHT.Weekdays='Saturday'

select FLIGHT.Flight_number, Fare_code
from FARE, FLIGHT
where FARE.Flight_number=FLIGHT.Flight_number 
and FARE.Restrictions=0

select distinct Customer_name, FLIGHT.Flight_number, Airline, Amount 
from FARE, FLIGHT, SEAT_RESERVATION
where SEAT_RESERVATION.Flight_number=FLIGHT.Flight_number 
and FARE.Flight_number=FLIGHT.Flight_number
and SEAT_RESERVATION.Customer_name like 'A%'

select Airplane_type, Departure_airport_code, Arrival_airport_code, Max_seats 
from LEG_INSTANCE, AIRPLANE, AIRPLANE_TYPE
where AIRPLANE.Airplane_id=LEG_INSTANCE.Airplane_id 
and AIRPLANE.Airplane_type=AIRPLANE_TYPE.Airplane_type_name
and AIRPLANE.Airplane_id=106

select distinct Amount, Seat_number, FLIGHT.Flight_number, Airline 
from FARE, SEAT_RESERVATION, FLIGHT
where FLIGHT.Flight_number=FARE.Flight_number
and FLIGHT.Flight_number=SEAT_RESERVATION.Flight_number
and SEAT_RESERVATION.Leg_number=1 
and FARE.Amount<100

select AIRPORT.Airport_code, Name, Airplane_type_name, Flight_number 
from AIRPORT, CAN_LAND, LEG_INSTANCE
where AIRPORT.Airport_code=CAN_LAND.Airport_code
and AIRPORT.Airport_code=LEG_INSTANCE.Departure_airport_code
and LEG_INSTANCE.Departure_airport_code=CAN_LAND.Airport_code
and CAN_LAND.Airport_code='IST'

select Airplane_type, FLIGHT_LEG.Arrival_airport_code as Planned_landing_zone, LEG_INSTANCE.Arrival_airport_code as Obligatory_landing_zone, FLIGHT.Flight_number, Airline 
from FLIGHT, FLIGHT_LEG, LEG_INSTANCE, AIRPLANE
where FLIGHT.Flight_number=FLIGHT_LEG.Flight_number
and FLIGHT.Flight_number=LEG_INSTANCE.Flight_number
and AIRPLANE.Airplane_id=LEG_INSTANCE.Airplane_id
and FLIGHT_LEG.Leg_number=LEG_INSTANCE.Leg_number 
and LEG_INSTANCE.Arrival_airport_code!=FLIGHT_LEG.Arrival_airport_code

select Customer_name, LEG_INSTANCE.Flight_number, LEG_INSTANCE.Leg_number, Amount, Total_number_of_seats
from FARE, AIRPLANE, SEAT_RESERVATION, LEG_INSTANCE
where LEG_INSTANCE.Flight_number=SEAT_RESERVATION.Flight_number
and LEG_INSTANCE.Leg_number=SEAT_RESERVATION.Leg_number
and FARE.Flight_number=LEG_INSTANCE.Flight_number
and LEG_INSTANCE.Airplane_id=AIRPLANE.Airplane_id
and LEG_INSTANCE.Flight_number='AZ608'

select AIRPORT.Airport_code, Name, AIRPLANE_TYPE.Airplane_type_name, Max_seats, Total_number_of_seats
from AIRPORT, AIRPLANE_TYPE, AIRPLANE, CAN_LAND
where AIRPORT.Airport_code=CAN_LAND.Airport_code
and AIRPLANE_TYPE.Airplane_type_name=AIRPLANE.Airplane_type
and AIRPLANE_TYPE.Airplane_type_name=CAN_LAND.Airplane_type_name
and Max_seats-Total_number_of_seats>150

select FLIGHT.Flight_number, Airline, Amount, Weekdays
from FARE, FLIGHT
where FARE.Flight_number=FLIGHT.Flight_number 
and FLIGHT.Weekdays in (
	select Weekdays
	from FLIGHT
	where Weekdays='Wednesday'
)

select Company, Airplane_type, Total_number_of_seats
from AIRPLANE, AIRPLANE_TYPE
where AIRPLANE.Airplane_type=AIRPLANE_TYPE.Airplane_type_name
and AIRPLANE.Total_number_of_seats in (
	select Total_number_of_seats
	from AIRPLANE
	where Total_number_of_seats<300
)

select FLIGHT.Flight_number, Fare_code
from FARE, FLIGHT
where FARE.Flight_number=FLIGHT.Flight_number 
and FARE.Restrictions in (
	select Restrictions
	from FARE
	where Restrictions=1
)

select distinct Customer_name, FLIGHT.Flight_number, Airline, Amount 
from FARE, FLIGHT, SEAT_RESERVATION
where SEAT_RESERVATION.Flight_number=FLIGHT.Flight_number 
and FARE.Flight_number=FLIGHT.Flight_number
and SEAT_RESERVATION.Customer_name in (
	select Customer_name
	from SEAT_RESERVATION
	where Customer_name like 'S%'
)

select Customer_name, Seat_number
from SEAT_RESERVATION
where exists (
	select *
	from LEG_INSTANCE
	where SEAT_RESERVATION.Flight_number=LEG_INSTANCE.Flight_number
	and SEAT_RESERVATION.Leg_number=LEG_INSTANCE.Leg_number
)

select Flight_number, Departure_airport_code, Arrival_airport_code
from FLIGHT_LEG
where not exists (
	select *
	from LEG_INSTANCE
	where FLIGHT_LEG.Flight_number=LEG_INSTANCE.Flight_number
	and FLIGHT_LEG.Leg_number=LEG_INSTANCE.Leg_number
	and FLIGHT_LEG.Arrival_airport_code=LEG_INSTANCE.Arrival_airport_code
)

select *
from AIRPORT full outer join CAN_LAND
on AIRPORT.Airport_code=CAN_LAND.Airport_code

select *
from LEG_INSTANCE left outer join AIRPORT
on AIRPORT.Airport_code=LEG_INSTANCE.Departure_airport_code

select *
from FLIGHT right outer join SEAT_RESERVATION
on FLIGHT.Flight_number=SEAT_RESERVATION.Flight_number

/*VIEWS*/
create view view1 as
	select Flight_number, Fare_code, Amount 
	from FARE
	where Restrictions=0
	
create view view2 as
	select Flight_number, Departure_airport_code, Scheduled_departure_time, Arrival_airport_code, Scheduled_arrival_time
	from FLIGHT_LEG
	where Leg_number=2
	
create view view3 as
	select Airplane_type_name, Max_seats
	from AIRPLANE_TYPE
	where Company='Boeing'