/**
* Name: COVID19general
* Based on the internal empty template. 
* Author: Piotr Palka
* Tags: 
*
*  ------------------------------------------------------------------------------
* Zaleznosc od warunkow pogodowych: 
* Na smiertelnosc negatywnie wplywa wyzsza temperatura powietrza, a pozytywnie wplywa na nia wyzsza wilgotnosc wzgledna. 
Kazdy dodatkowy stopien Celsjusza zmniejsza smiertelnosc o 3,74%, 
a wzrost wilgotnosci wzglednej o 1% zwieksza smiertelnosc o 1,85%. 
Temperatura jest dodatnio skorelowana ze wskaznikiem UV, dla ktorego jednostka wzrostu powoduje 14,72% spadek smiertelnosci.
Dodatkowo, wzrost odsetka osob w wieku powyzej 64 lat o 1% zwieksza smiertelnosc o 11,31%.
Kazde dodatkowe lozko dla 10 tys. mieszkancow w szpitalach zmniejszylo smiertelnosc o 2,22%.
Silne i wczesne rzadowe ograniczenia dotyczace podrozowania to srednia geometryczna smiertelnosci 61,8% nizsza niz wtedy, gdy ograniczenia byly slabe i wprowadzone pozno. Nie obserwuje sie wplywu gdy wprowadzono „srednie” obostrzenia w podrozowaniu.
zrodlo: https://www.researchgate.net/publication/340891765_Climatic_factors_influence_COVID-19_outbreak_as_revealed_by_worldwide_mortality
* 
* noszenie maseczki przez mieszkańców i dopasować parametry zarażalności (np. wg. pracy https://aip.scitation.org/doi/full/10.1063/5.0025476 )
*
*/


model COVID19general

global
{
	float step <- 15 #mn;
	int starting_cycle <- 0;
	date starting_date <- date([2020,4,1,0,0,0]) + starting_cycle * step;
	
	float current_temp <- 20.0;
	float current_hum <- 85.0;
	
	bool people_from_shp <- true; // true: generuje agenty na podstaiwe shp, false: generuje $person_num agentow
	string model_folder <- "pow_goldapski";  
	string strig_file <- "../strig_estonia.csv";
	string vacpol_file <- "vac_policy.csv";
	
	//string model_folder <- "pow_goldapski";
	//string model_folder <- "pow_pruszkowski";
	string csv_file_name <- "";
	
	bool use_strigency_index <- true;
	bool use_vaccinations <- false;
	
	bool isQuarantine <- true; //  
	/* kwarantanna: ograniczenia w wychodzeniu z domu: --------------------------
	 * ogr_pracy% - wychodzi rzadziej do pracy (pracuja zdalnie) - 100% wszyscy chodza do pracy, 0% - nikt nie wychodzi
	 * ogr_zakupy% - wychodza rzadziej do sklepu (zakupy zdalne, rzadsze za
	 * ogr_rozrywka% - wychodza rzadziej zeby sie rozerwac
	 * ogr_leczenie% - leczenie zdalne - teleporady
	 * ogr_kosciol% - msze on-line
	 */
	float ogr_pracyIkw2020 <- 1.0; 	 // parametr dla I kw 2020 - ile osob pracuje on-line
	float ogr_pracyIIkw2020 <- 1.0;	 // parametr dla II kw 2020 - ile osob pracuje on-line
	float ogr_pracyIIIkw2020 <- 1.0; /// parametr dla III kw 2020 - ile osob pracuje on-line
	float ogr_pracyIVkw2020 <- 1.0;  /// parametr dla IV kw 2020 - ile osob pracuje on-line
	float base_ogr_pracy <- 1.0; 	 // parametr bazowy - do niego ladujemy parametry, i na jej podstawie liczymy ostateczna ogr_pracy
	float ogr_pracy <- 0.3; 		 // parametr operacyjny - oznacza jaki procent osob faktycznie pracuje na miejscu
	
	float ogr_szkoly <- 0.1; 		// param operacyjny - na nim dzialamy, 100% - wszyscy chodza do szkoly, 0% - nikt nie chodzi do szkoly
	float base_ogr_szkoly <- 1.0 ;	//parametr bazowy - do niego ladujemy parametry, i na jej podstawie liczymy ostateczna ogr_szkoly
	
	float ogr_zakupy <- 0.6; 		// param operacyjny - na nim dzialamy, 100% - wszyscy robia zakupy fizycznie, 0% - nikt nie robi zakupow fizycznie
	float base_ogr_zakupy <- 1.0;	// parametr bazowy - do niego ladujemy parametry, i na jej podstawie liczymy ostateczna ogr_zakupy
	
	float ogr_rozrywka <- 0.0; 		// wg. dokumnetu USB
	float base_ogr_rozrywka <- 1.0;	
	
	float ogr_leczenie <- 0.64; 	// param operacyjny - na nim dzialamy, 100% - wszyscy chodza do lekarza, 0% nikt nie chodzi do lekarza
	float base_ogr_leczenie <- 1.0;	// parametr bazowy - do niego ladujemy parametry i na jego podstawie liczymy ogr_leczenie
	
	float ogr_kosciol <- 0.66; 		// param operacyjny - na nim dzialamy, 100% - wszyscy chodza fizycznie do kosciola, 0% nikt nie chodzi fizycznie do kosciola
	float base_ogr_kosciol <- 1.0;	// parametr bazowy - do niego ladujemy parametry i na jego podstawie liczymy ogr_kosciola
	float p_modliSie <- 0.1;	// procent osob religijnych - chodzacych do kosciola (10% - zgrubnie)		
	
	bool isMaskInside <- true; // Nakaz noszenia maseczek wewnatrz budynkow
	bool isMaskOutside <- true; // Nakaz noszenia maseczek na zewnatrz
	
	float pr_nosi_maske <- 0.6; 		// wg. dokumentu USB - procent osob noszacych maseczke
	float base_pr_nosi_maske <- 0.5; 	// parametr bazowy - do niego ladujemy parametr
	
	float maska_ogr_rozsiewania_wirusa <- 1.0 / 2.3; // na podstawie https://aip.scitation.org/doi/full/10.1063/5.0025476 
	float maska_ogr_zakazenia <- 1.0 / (7.3/2.3);    // https://aip.scitation.org/doi/full/10.1063/5.0025476
	/*
	 * Indeed, if we average the upper
and lower bounds of FE for the four most effective fabrics/samples
* (Cotton 4, Cotton 14, Synthetic Blend 2, and Surgical Mask), we
obtain an aggregate fi ltration effi ciency of 63%, which would cor-
respond to a unilateral (bilateral) protection factor of 2.7(7.3). Thus,
simple face masks made from any of these fabrics/materials could
signifi cantly lower overall transmission rates.
	 */ 
	 
	float maska_prawidlowo <- 0.647; // na podstawie: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7241223/ 
	/* 
	 * In this study, 64.7% of participants obtained an overall moderate-to-poor 
	 * score regarding the correct usage of a surgical face mask
	 */
	float pr_go_to_hospI <- 0.02; // probability to go to the infectious hospital from state I
	float pr_go_to_hospP <- 0.08; // probability to go to the infectious hospital from state P
									// na podstawie raportu MZ, raport Michal Rogalski "COVID-19 w Polsce" 
									// https://docs.google.com/spreadsheets/d/1ierEhD6gcq51HAm433knjnVwey4ZE5DCnu1bW7PRG3E/edit#gid=1136959919
	float pr_inf_in_inf_hosp <- 0.0001; // probability modifier of infection from person being in infectious hospital
	
	 
    int person_num <- 1000;
   	int exposed <- 14;
    int sympt_inf  <- 1;
    int asympt_inf <- 8;
	int removed <- 10;
	int posdiag <- 0;
	int dead <- 0;
    int immune <- 0; // ile osob jest odpornych na COVID-19
    	
	/*	COVID-19 ver_powiat */
	file shape_file_budynki <- file("../includes/" + model_folder + "/budynki_region.shp");
	file shape_file_miejsca_pracy <- file("../includes/" + model_folder + "/miejsca_pracy_region.shp");
	file shape_file_szkoly <- file("../includes/" + model_folder + "/szkoly_przedszk_region.shp");
	file shape_file_zdrowie <- file("../includes/" + model_folder + "/zdrowie_region.shp");
	file shape_file_stacje_pkp <- nil;
	file shape_file_koscioly <- file("../includes/" + model_folder + "/koscioly_region.shp");
	file shape_file_parki <- file("../includes/" + model_folder + "/parki_lasy_region.shp");
	file shape_file_muzea <- file("../includes/" + model_folder + "/muzea_biblioteki_region.shp");
	file shape_file_sklepy <- file("../includes/" + model_folder + "/handel_region.shp");
	
	file shape_file_drogi <- file("../includes/" + model_folder + "/drogi_polyline.shp");
	
	geometry shape <- envelope(shape_file_drogi);
	
	
	float min_incubation_time <- 4.5 * (1 #days) ;
	float max_incubation_time <- 5.8 * (1 # days) ; ///https://www.acpjournals.org/doi/full/10.7326/M20-0504
	
	float min_recovery_time <- 10 * (1 #days) ;
	float max_recovery_time <- 14 * (1 #days) ;
	
	float min_diagnose_time <- 1 * (1 #days);
	float max_diagnose_time <- 3 * (1 #days);
	
	float min_time_to_death <- 3 * (1 #days);
	float max_time_to_death <- 14 * (1 #days);
	
	
	// do weryfikacji i nauczenias
	float ro <- 0.8;
	float dI <- 0.01356770 ; 
	float dP <- 0.0041681711  ;
	float eps <- 0.5; // TODO!!!!
	
	float beta <- 20*0.5965935;  // trzeba podzielic tak, zeby odpowiadalo za pr/dobe
	float miu  <- 20*0.5965935 ;	// trzeba podzielic tak, zeby odpowiadalo za pr/dobe
	
	int odleglosc_zarazania <- 8; // odleglosc zarazania (w m) domyslnie 8
	float inf_distance_factor <- 0.5; // modyfikator, w zaleznosci od odleglosci miedzy agentami DIST, zwraca prawdopodobienstwo 
										// zakazenia rowny exp(inf_distance_factor * DIST), domyslnie 0.5
	
	//int current_hour update: (time / #hour) mod 24;
	//int current_day update: (time / #days) mod 7;
	
	float min_work_start <- 1 * 1#h;
	float max_work_start <- 3 * 1#h ;
	float min_work_end <- 14 * 1#h;
	float max_work_end <- 16 * 1#h;

	float min_rozrywka_start <- 18 * 1#h;
	float max_rozrywka_start <- 20 * 1#h;
	float min_rozrywka_end <- 21 * 1#h;
	float max_rozrywka_end <- 23 * 1#h;

	float min_lekarz_start <- 8 * 1#h;
	float max_lekarz_start <- 10 * 1#h;
	float min_lekarz_end <- 11 * 1#h;
	float max_lekarz_end <- 13 * 1#h;
	
	float min_roz_weekend_start <- 9 * 1#h;
	float max_roz_weekend_start <- 13  * 1#h;
	float min_roz_weekend_end <-  14 * 1#h;
	float max_roz_weekend_end <- 21  * 1#h;
		
	list<int> msze_start <- [7, 9, 12, 17];
	list<int> msze_end <- [9, 11, 14, 19];
	
	list<budynki> domy <- nil;
	list<miejsca_pracy> prace <- nil;
	list<szkoly> edukacje <- nil;
	list<stacje_pkp> stacje <- nil;
	list<koscioly> nabozenstwa  <- nil;

	float is_rozrywka <- 0.5;
	
	float pojdzie_do_lekarza <- 0.15;
	
	float min_speed <- 3.0 # km / # h;
	float max_speed <- 5.0 # km / # h;
	graph the_graph;
	
	int number_IV <- 0;
	int number_S <- 0;
	int number_E <- 0;
	int number_I <- 0;
	int number_A <- 0;
	int number_R <- 0;
	int number_P <- 0;
	int number_D <- 0;
	
	int integral_I <- 0;
	int integral_A <- 0;
	int integral_D <- 0;
	int integral_P <- 0;
	int integral_H <- 0;
	
	int int_I <- 0;
	int int_A <- 0;
	int int_D <- 0;
	int int_P <- 0;
	
	// do dopracowania!!!!!!!
	float p_muzeum <- 0.02739;  	// prawdopodobienstwo (dzienne) pojscia do instytucji kultury (raz w roku)
	float p_park <- 0.2857;		// prawdopodobienstwo (dzienne) pojscia na spacer do parku/lasu (dwa razy w tygodniu)
	float p_zakupy <- 0.5714;		// prawdopodobienstwo (dzienne) pojscia na zakupy
	float pr_samochod <- 0.8;   // procent osob jezdzacych samochodem
	
	// artykul o noszeniu maseczek: https://aip.scitation.org/doi/full/10.1063/5.0025476
		
	// poczatkowe wyznacznie osob zakazonych
	reflex set_history when: cycle = 0 {
		loop times: immune {
			person hst <- one_of (person where each.SEIR_S);
			hst.SEIR_IV <- true;
			hst.SEIR_S <- false;
		}
		loop times: dead {
			person hst <- one_of (person where each.SEIR_S);
			hst.SEIR_D <- true;
			hst.SEIR_S <- false;
		}
		loop times: exposed {
			person hst <- one_of (person where each.SEIR_S);
			hst.SEIR_E <- true;
			hst.SEIR_S <- false;
			hst.expose_begin <- time - floor(rnd(0, hst.incubation_time - step) / step) * step;
	   	    hst.kiedy_zakazony <- hst.expose_begin ;
	   	    hst.gdzie_zakazony <- location;	
		}
		loop times: removed {
			person hst <- one_of (person where each.SEIR_S);
			hst.SEIR_R <- true;
			hst.SEIR_S <- false;
		}
		loop times: posdiag {
			person hst <- one_of (person where each.SEIR_S);
			hst.SEIR_P <- true;
			hst.SEIR_S <- false;			
			hst.diagnose_begin <- time;
			
			if flip(hst.death_P){
				hst.diagnose_begin <- time - floor(rnd(0, max(0, hst.time_to_death - hst.diagnose_time)) / step) * step;
				hst.SEIR_PtoD <- true;
			} else {
				// wyzdrowienie, po przejsciu kwarantanny
				hst.diagnose_begin <- time - floor(rnd(0, hst.recovery_time - hst.diagnose_time) /step) * step;
				hst.SEIR_PtoR <- true;
			}
		}
		loop times: sympt_inf {
			person hst <- one_of (person where each.SEIR_S);
			
			
            hst.SEIR_S <- false;
            hst.SEIR_I <-  true; 
            hst.color <- #red;
            integral_I <- integral_I + 1; 
            
            //TODO: sprawdzic czy to samo jak w E_IA
 			if flip(eps) { 
 				hst.SEIR_ItoP <- true; 
 				hst.infection_begin <- time - floor(rnd(0, hst.diagnose_time - step) / step) * step;
 			}
    		else if flip(dI) { 
    			hst.SEIR_ItoD <- true;
				hst.infection_begin <- time - floor(rnd(0, hst.time_to_death - step) / step) * step;    			
    		}
    		else { 
    			hst.SEIR_ItoR <- true;
    			hst.infection_begin <- time - floor(rnd(0, hst.recovery_time - step) / step) * step ; 		
    		}
		}
		loop times: asympt_inf{
			person hst <- one_of (person where each.SEIR_S);
			hst.infection_begin <- time - floor(rnd(0, hst.recovery_time - step) / step) * step;
        
            hst.SEIR_S <- false;
            hst.SEIR_A <-  true; 
            integral_A <- integral_A + 1; 
            
            hst.color <- #orange;  				
		}
	}
	
	/*reflex save_shp when: cycle mod 8064 = 0  {
		loop ag over: person{
			if (ag.gdzie_zakazony != nil) { 
				save species_of(ag) to: "save"+cycle+"shapefile.shp" type: "shp" attributes: ["id"::id, "gdziezakazony"::gdzie_zakazony, "kiedy"::kiedy_zakazony, "plec"::sex, "wiek"::age] crs: "EPSG:4326";		 
			} 
		}
    }*/
    /*reflex save_csv when: cycle mod 8064 = 0 {
    	loop ag over: person {
    		if (ag.gdzie_zakazony != nil) {
    			save [ag.id, ag.gdzie_zakazony, ag.kiedy_zakazony, ag.sex, ag.age] to: csv_file_name + "save"+cycle+".csv" type: "csv" rewrite: false;
			}
    	}
    }*/
    reflex quaterI_change_params when: current_date = [2020, 1, 1, 0, 0, 0] {
    	base_ogr_pracy <- ogr_pracyIkw2020;
    }
    reflex quaterII_change_params when: current_date = [2020, 4, 1, 0, 0, 0] {
    	base_ogr_pracy <- ogr_pracyIIkw2020;
    }
    reflex quaterIII_change_params when: current_date = [2020, 7, 1, 0, 0, 0] {
    	base_ogr_pracy <- ogr_pracyIIIkw2020;
    }
    reflex quaterIV_change_params when: current_date = [2020, 10, 1, 0, 0, 0] {
    	base_ogr_pracy <- ogr_pracyIVkw2020;
    }
    
	init
	{
		ogr_pracy <- 1.0 - base_ogr_pracy;
		ogr_szkoly <- 1.0 - base_ogr_szkoly;
		ogr_leczenie <- 1.0 - base_ogr_leczenie;
		ogr_zakupy <- 1.0 - base_ogr_zakupy;
		ogr_rozrywka <- 1.0 - base_ogr_rozrywka;
		ogr_kosciol <- 1.0 - base_ogr_kosciol;		
		pr_nosi_maske <- base_pr_nosi_maske;
		
		create budynki from: shape_file_budynki with: [id::int(read("ID"))] {
			color <- #gray;
			lcolor <- #black;
		}
		create miejsca_pracy from: shape_file_miejsca_pracy with: [id::int(read("ID"))] {
			color <- #red;
			lcolor <- #black;
		} 
		create szkoly from: shape_file_szkoly with: [id::int(read("ID"))] {
			color <- #orange;
			lcolor <- #black;
		}
		create zdrowie from: shape_file_zdrowie with: [id::int(read("ID"))] {
			color <- #white;
			lcolor <- #black;
		}
		if (model_folder != 'pow_goldapski'){
			shape_file_stacje_pkp <- file("../includes/" + model_folder + "/PKP_region.shp");	
			create stacje_pkp from: shape_file_stacje_pkp with: [id::int(read("ID"))] {
				color <- #brown;
				lcolor <- #black;
			}
		}
		create koscioly from: shape_file_koscioly with: [id::int(read("ID"))] {
			color <- #yellow;
			lcolor <- #black;
		}
		create muzea from: shape_file_muzea with: [id::int(read("ID"))] {
			color <- #lime;
			lcolor <- #black;
		}
		create parki from: shape_file_parki with: [id::int(read("ID"))] {
			color <- #green;
			lcolor <- #black;
		}
		create sklepy from: shape_file_sklepy with: [id::int(read("ID"))] {
			color <- #cyan;
			lcolor <- #black;
		}
		
		if (use_strigency_index){
			create strigency from: csv_file("../includes/" + model_folder + "/" + strig_file, ";", true) with:
			[
				datum::date(get("Date")),
				school_closing::int(read("C1_School_closing")),
				workplace_closing::int(read("C2_Workplace_closing")),
				cancel_pub_events::int(read("C3_Cancel_public_events")),
				stay_home::int(read("C6_Stay_at_home_requirements")),
				face_covering::int(read("H6_Facial_Coverings")),
			 	vaccination_policy::int(read("H7_Vaccination_policy"))
			];
		}
		if (use_vaccinations){
			create vac_policy from: csv_file("../includes/" + model_folder + "/" + vacpol_file, ";", true) with:
			[
				datum::date(get("Date")),
				num_people::int(read("num_people"))
			];
		}
				
		create pogoda from: csv_file("../includes/" + model_folder + "/pogoda.csv", ";", true) with:
		[
    		d::date(read("Date")),
    		temperature::float(read("Temperature")),
    		humidity::float(read("Hummidity"))
		];
		
		
		create drogi from: shape_file_drogi with: [id::int(read("ID"))];
		the_graph <- as_edge_graph(drogi);
		
		// przypisanie 
		domy <- budynki;
		prace <- miejsca_pracy;
		edukacje <- szkoly;
		stacje <- stacje_pkp;
		nabozenstwa <- koscioly;
		
		if (people_from_shp = true) {
			file shape_file_agenty <- file ("../includes/" + model_folder + "/mieszkancy_point.shp");
			
			create person from: shape_file_agenty with: [id::int(read("ID")), sex::string(read("PLEC")), 
				wiek::string(read("WIEK")), id_bud::int(read("ID_BUD")), id_szk::int(read("ID_SZK")),
				id_prac::int(read("ID_PRAC")), poza_powiat::int(read("POWIAT")), bezrobotny::int(read("BEZROBOTNY")),
				id_pkp::int(read("ID_PKP"))]{
		
				do GOTO_D;
				do TRV_TO_WALK;
					
				mieszka <- domy[id_bud mod length(domy)];
				//location <- any_location_in(mieszka);
				
				if (id_prac > 0){
					pracuje <- prace[id_prac mod length(prace)];
				} else { pracuje <- nil; }
				
				if (id_szk > 0){
					uczySie <- edukacje[id_szk mod length(edukacje)];
				} else {uczySie <- nil; }
				
				if (flip(p_modliSie) = true){
					//modliSie <- nabozenstwa closest_to(location);
					modliSie <- one_of(koscioly);
				} else {
					modliSie <- nil;
				}
				if (poza_powiat = 1 and id_pkp > 0){
					jedziePKP <- stacje_pkp where (each.id = id_pkp);
				}
				
				// losowanie lokalizacji
				spaceruje <- one_of(parki);
				oglada_obrazy <- one_of(muzea);
				leczySie <- one_of(zdrowie);
				
				if (sex = "M") {
					wsp_osobniczy <- 1.07;					
				} else {
					wsp_osobniczy <- 0.93;
				}
				 
				if (wiek = "0-14")  { 
					age <- rnd(0, 14); 
					wsp_osobniczy <- wsp_osobniczy * 0.1169; 
				}
				else if (wiek = "15-64") { 
					age <- rnd(15, 64);
					wsp_osobniczy <- wsp_osobniczy * 2.39; 
				}
				else if (wiek = "64+")   { 
					age <- rnd(65, 100);
					wsp_osobniczy <- wsp_osobniczy * 0.4932; 	 
					death_I <- dI * 1.1131;  
					death_P <- dP * 1.1131;
				} 
				//  wzrost odsetka osób w wieku powyżej 64 lat o 1% zwiększa śmiertelność o 11,31%.
				// zaleznosc zakazenia od wieku, np. https://biqdata.wyborcza.pl/biqdata/7,159116,26497931,smiertelnosc-i-zachorowania-wg-wieku-mamy-dane-z-krajowego.html
								
				else {age <- rnd(0,100); }
								
				SEIR_S <- true;
	        	SEIR_E <-  false;
	            SEIR_I <-  false; 
	            SEIR_A <-  false; 
	            SEIR_R <-  false; 
	            SEIR_P <-  false; 
	            color <- #black;
			}
		} 		
		
	}
	species infections {
		list<int> id_kto_zakazil;
		list<int> id_kogo_zakazil;
		int kiedy;
		string typ_zakazenia;
		
		aspect base {
			draw circle(50#m) color: #red; 
		} 
	}
	
	species budynki schedules: []
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species miejsca_pracy schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species zdrowie schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor ; }
	}
	species szkoly schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species stacje_pkp schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species koscioly  schedules: []
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species muzea  schedules: []
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species parki  schedules: []
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species rozrywki schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species sklepy schedules: [] 
	{
		int id;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		aspect base { draw shape color: color border: lcolor; }
	}
	species drogi  schedules: []
	{ 
		int id;
		rgb color <- rgb(0, 0, 0);
		int height <- 0;
		aspect base { draw shape color: color; }
	}
	
	species pogoda
	{
		date d;
		float temperature;
		float humidity;
		
		reflex get_weather when: current_date = d {
			current_temp <- temperature;
			current_hum <- humidity;
		}
	}
	/*
	 * data on strigency, https://ourworldindata.org/grapher/covid-stringency-index?tab=table&stackMode=absolute&time=2020-01-22..latest&country=~POL&region=World 
	  */
	species strigency
	{
		date datum;
		int school_closing;
		/* 
		 * 0 - No measures
		 * 1 - recommend closing
		 * 2 - Require closing (only some levels or categories, eg just high school, or just public schools)
		 * 3 - Require closing all levels
		 * No data - blank 
		 * */

		int workplace_closing;
		/*
		 * 0 - No measures
		 * 1 - recommend closing (or work from home)
		 * 2 - require closing (or work from home) for some sectors or categories of workers
		 * 3 - require closing (or work from home) all but essential workplaces (eg grocery stores, doctors)
		 * No data - blank
		 */
		 
		int cancel_pub_events;
		/* 
		 * 0- No measures
		 * 1 - Recommend cancelling
		 * 2 - Require cancelling
		 * No data - blank 
		  */
		  
		int stay_home;
		/*
		 * 0 - No measures
		 * 1 - recommend not leaving house
		 * 2 - require not leaving house with exceptions for daily exercise, grocery shopping, and ‘essential’ trips
		 * 3 - Require not leaving house with minimal exceptions (e.g. allowed to leave only once every few days, or only one person can leave at a time, etc.)
		 */
		 
		int face_covering;
		 /*
		  * 0- No policy
		  * 1- Recommended
		  * 2- Required in some specified shared/public spaces outside the home with other people present, or some situations when social distancing not possible
		  * 3- Required in all shared/public spaces outside the home with other people present or all situations when social distancing not possible
		  * 4- Required outside the home at all times regardless of location or presence of other people
		  */
		  
		 int vaccination_policy;
		 /*
		  * 0 - No availability
		  * 1 - Availability for ONE of following: key workers/ clinically vulnerable groups / elderly groups
		  * 2 - Availability for TWO of following: key workers/ clinically vulnerable groups / elderly groups
		  * 3 - Availability for ALL of following: key workers/ clinically vulnerable groups / elderly groups
		  * 4 - Availability for all three plus partial additional availability (select broad groups/ages)
		  * 5 - Universal availability
 		  */
		  
		reflex get_strigency when: current_date = datum {
				
			if (school_closing > 0 or workplace_closing > 0 or stay_home > 0){
				isQuarantine <- true;
			}
			
			ogr_szkoly <- 1.0 - school_closing * base_ogr_szkoly/3;
			ogr_pracy  <- 1.0 - workplace_closing * base_ogr_pracy/3;
			ogr_zakupy <- 1.0 - stay_home * base_ogr_zakupy/2;
			ogr_rozrywka <- 1.0 - cancel_pub_events * base_ogr_rozrywka/3;
			
			if (face_covering = 0) {
				pr_nosi_maske <- 0.0;
				isMaskInside <- false;
				isMaskOutside <- false;
			} else if (face_covering = 1){
				pr_nosi_maske <- 0.4 * base_pr_nosi_maske;
				isMaskInside <- false;
				isMaskOutside <- false;
			} else if (face_covering = 2){
				pr_nosi_maske <- 0.6 * base_pr_nosi_maske;
				isMaskInside <- false;
				isMaskOutside <- true;
			} else if (face_covering = 3){
				pr_nosi_maske <- 0.8 * base_pr_nosi_maske;
				isMaskInside <- true;
				isMaskOutside <- true;
			} else if (face_covering = 4){
				pr_nosi_maske <- 1.0 * base_pr_nosi_maske;
				isMaskInside <- true;
				isMaskOutside <- true;
			} 
			
		}
	}
	species vac_policy {
		date datum;
		int num_people;
		
		reflex get_vac_policy when: current_date = datum {
			loop times: num_people {
				person hst <- one_of (person where (!each.SEIR_D and !each.vaccinated));
				if (flip( 0.7 )){
					hst.SEIR_IV <- true;
				}
				hst.vaccinated <- true;			
			}
		}
	}
	species	person skills: [moving] parallel: true 
	{
		//----------------------------------------------------------------------------------------------------------- 
		//----------------------------------- kolejne stany modelu --------------------------------------------------
		//----------------------------------------------------------------------------------------------------------- 
		bool SEIR_IV <- false; // Immune/vaccinated
		bool SEIR_S <- true;  // Susceptible
		bool SEIR_E <- false; // Exposed
    	bool SEIR_I <- false; // Symptomatic (I)nfected
    	bool SEIR_A <- false; // (A)symptomatic Infected
    	bool SEIR_P <- false; // (P)ositively Diagnozed
    	bool SEIR_D <- false; // Dead - nie wystapi, agent umiera
    	bool SEIR_R <- false; // Removed/recovered
    	
    	bool vaccinated <- false;
    	bool _TO_INF_HOSP <- false; // should go to the infectious hospital
    	bool _WENT_TO_INF_HOSP <- false; // went to the infectious hospital
    	
    	bool SEIR_ItoP <- false; // stan gdy jest juz zadecydowano o przejsciu do stanu P, ale agent wciaz jest w stanie I
    	bool SEIR_ItoD <- false; // stan gdy jest juz zadecydowano o przejsciu do stanu D, ale agent wciaz jest w stanie I
    	bool SEIR_ItoR <- false; // stan gdy jest juz zadecydowano o przejsciu do stanu R, ale agent wciaz jest w stanie I
    	bool SEIR_PtoD <- false; // stan gdy jest juz zadecydowano o przejsciu do stanu D, ale agent wciaz jest w stanie P
    	bool SEIR_PtoR <- false; // stan gdy jest juz zadecydowano o przejsciu do stanu R, ale agent wciaz jest w stanie P
    	
    	//----------------------------------------------------------------------------------------------------------------
    	// ------------------------------------- stany dotyczace podrozowanie agenta -------------------------------------
    	//----------------------------------------------------------------------------------------------------------------
    	bool TRV_W <- true; // idzie spacerem
    	bool TRV_C <- false; // jedzie samochodem 
    	bool TRV_P <- false; // jedzie transportem publicznym
    	
    	int kiedy_zakazony <- -1;
    	point gdzie_zakazony <- nil;
    	float wsp_osobniczy <- 1.0; // wspolczynnik osobniczy zakazenia, rozwazamy przedzial wiekowy i plec
    	float death_I <- dI;
    	float death_P <- dP;
    	
    	bool nosi_maseczke <- flip(pr_nosi_maske); // nosi maseczke (przy nakazie)
    	
    	//----------------------------------------------------------------------------------------------------------------
    	// ------------------------------------- stany dotyczace celu agenta -------------------------------------
    	//----------------------------------------------------------------------------------------------------------------
    	bool DST_D <- false; // dom
    	bool DST_P <- false; // praca
    	bool DST_S <- false; // sklep
    	bool DST_L <- false; // lekarz
    	bool DST_R <- false; // rozrywka
    	bool DST_K <- false; // kosciol
    	bool DST_Q <- false; // kwarantanna?
    	point the_target <- nil;
    	bool in_train <- false;
		
    	action GOTO_D{
    		DST_D <- true;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- false;    		
    	}
    	action GOTO_P{
    		DST_D <- false;
    		DST_P <- true;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- false;
    	}
		action GOTO_S{
    		DST_D <- false;
    		DST_P <- false;
    		DST_S <- true;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- false;
    	}
		action GOTO_L{
    		DST_D <- false;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- true;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- false;    		
    	}
		action GOTO_R{
    		DST_D <- false;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- true;
    		DST_K <- false;
    		DST_Q <- false;    		
    	}
		action GOTO_Q{
    		DST_D <- false;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- true;    		
    	}
		action GOTO_K{
    		DST_D <- false;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- true;
    		DST_Q <- false;    		
    	}
    	action STAY_WHERE_YOU_ARE{
    		DST_D <- false;	
    		DST_P <- false;
    		DST_S <- false;
    		DST_L <- false;
    		DST_R <- false;
    		DST_K <- false;
    		DST_Q <- false;    		
    	}
    	
		int nr_mszy <- rnd(0,3); // kosciol - niedziela
		    	
		
    	// do poprawienia
    	float time_to_death <- floor(rnd(min_time_to_death, max_time_to_death) / step) * step;
    	float incubation_time <- floor(rnd(min_incubation_time, max_incubation_time) / step) * step;
	   	float recovery_time <- floor(rnd(min_recovery_time, max_recovery_time) / step) * step;
		float diagnose_time <- floor(rnd(min_diagnose_time, max_diagnose_time) / step) * step;
		
		float infection_begin <- -1;
    	float diagnose_begin <- -1;
    	float expose_begin <- -1; 
    
		int id;
		float speed;
		rgb color;
		
		budynki mieszka <- nil;	
		miejsca_pracy pracuje <- nil;
		zdrowie leczySie <- nil;
		szkoly uczySie <- nil;
		koscioly modliSie <- nil;
		stacje_pkp jedziePKP <- nil;
		sklepy kupuje <- nil;
		muzea oglada_obrazy <- nil;
		parki spaceruje <- nil; 
		
		float start_work        <- floor(rnd(min_work_start, max_work_start) / step) * step;
		float end_work          <- floor(rnd(min_work_end, max_work_end) / step) * step;
		float start_rozrywka    <- floor(rnd(min_rozrywka_start, max_rozrywka_start) / step) * step;
		float end_rozrywka      <- floor(rnd(min_rozrywka_end, max_rozrywka_end) / step) * step;
		float start_lekarz      <- floor(rnd(min_lekarz_start, max_lekarz_start) / step) * step;
		float end_lekarz        <- floor(rnd(min_lekarz_end, max_lekarz_end) / step) * step;
		float start_weekend_roz <- floor(rnd(min_roz_weekend_start, max_roz_weekend_start) / step) * step;
		float end_weekend_roz   <- floor(rnd(min_roz_weekend_end, max_roz_weekend_end) / step) * step;
		
		
		path path_followed <- nil;
		
		bool isMarried;
		int numOfChildren;
			
		string wiek;
		int id_bud;
		int id_prac;
		int id_pkp;
		int id_szk;
		int bezrobotny;
		int poza_powiat; 
			
		int age min: 0.0 max: 100.0;
		string sex;
		int morbidity;
		
		//list<geometry> segments <- nil;
			
		action TRV_TO_WALK{
			TRV_W <- true;
			TRV_C <- false;
			TRV_P <- false;
			speed <- rnd(min_speed, max_speed) # km / # h;
			return 1;
		}
		action TRV_TO_CAR{
			TRV_W <- false;
			TRV_C <- true;
			TRV_P <- false;
			speed <- rnd(min_speed * 10, max_speed  * 10) # km / # h;
			return 1;
		}	
		action TRV_TO_PUBLIC{
			TRV_W <- false;
			TRV_C <- false;
			TRV_P <- true;
			speed <- rnd(min_speed * 10, max_speed  * 10) # km / # h;
			return 1;
		}	
		action CHANGE_TRV(float distance) {
			if (distance < 1#km){ do TRV_TO_WALK; }
			else {			// samochod/pociag/tramwaj
				if (flip(pr_samochod)) { do TRV_TO_CAR; }	
				else { do TRV_TO_PUBLIC; }
			}	
		}
		
		aspect base { 
			draw circle(15#m) color: color;				
		}	
//		reflex distance when: cycle = 0{
//			write "["+self.id+"]najblizszy agent: " + ((person closest_to self) distance_to self) / 1#m;
//		}	

		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za rytm zycia agenta *******************************
   	    //--------------------------------------------------------------------------------------------------------
		// w kazdym cyklu trzeba wylosowac - ze wzgledu na zmienna polityke rzadu
		reflex zaloz_maseczke when: time mod (1*#day) = 0 {
			nosi_maseczke <- flip(pr_nosi_maske);
		}
		//--------------------------------------------------------------------------------------------------------
		// *************************** praca agenta **************************************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex dom_praca when: !SEIR_D and !SEIR_P and !SEIR_I // nie jest martwy, nie jest pod kwarantanna, 
																  // nie jest pozytywnie zdiagnozowany, ani zakazony 
								and DST_D 			  // jest w domy
								and pracuje != nil
								and flip(isQuarantine?ogr_pracy:1.0)
								 and !_TO_INF_HOSP
			 
								and ( time  mod (24 * #hour)) = start_work // zaczyna prace 
								and ((time / #days) mod 7) < 5  {		  // od poniedzialku do piatku
			do GOTO_P;
			if (poza_powiat = 1 and jedziePKP != nil) {
				the_target <- point(jedziePKP);    						
			} 
			else {
				the_target <- point(pracuje);	
			}
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** praca agenta **************************************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex dom_szkola when: !SEIR_D and !SEIR_P and !SEIR_I // nie jest martwy, nie jest pod kwarantanna, 
																  // nie jest pozytywnie zdiagnozowany, ani zakazony 
								and DST_D 			  // jest w domy
								and uczySie != nil
								 and !_TO_INF_HOSP
			 
								and flip(isQuarantine?ogr_szkoly:1.0)
								and ( time  mod (24 * #hour)) = start_work // zaczyna prace 
								and ((time / #days) mod 7) < 5  {		  // od poniedzialku do piatku
			do GOTO_P;
			
			if (poza_powiat = 1 and jedziePKP != nil) {
				the_target <- point(jedziePKP);
			} 
			else { 
				the_target <- point(uczySie);
			}
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		reflex praca_dom when: mieszka != nil 					// ma gdzie mieszkac  
							and ( time  mod (24 * #hour)) = end_work // konczy prace 
							and DST_P						// pracuje / uczy sie
		{
			do GOTO_D;
			the_target <- point(mieszka);
			
			if (poza_powiat = 1 and jedziePKP != nil) {
				in_train <- false;
			}
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** zdrowie agenta **************************************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex praca_lekarz  when: leczySie != nil	// wie gdzie pojsc do lekarza 
						and (DST_P or DST_D) 		// jest w pracy lub w domu
						 and !_TO_INF_HOSP
						 and !in_train //we exclude this situation 
			 
						and flip(isQuarantine?ogr_leczenie:1.0)
						and ( time  mod (24 * #hour)) = start_lekarz // rozpoczyna sie wizyta
						and flip(pojdzie_do_lekarza) 	// chce isc do lekarza (prawdopodobienstwo dotyczy dnia)
						 
		{
			do GOTO_L;
			the_target <- point(leczySie);
			do CHANGE_TRV distance: location distance_to the_target; 
			
		}
		reflex lekarz_praca when: pracuje != nil 
						and DST_L 
						and ( time  mod (24 * #hour)) = end_lekarz
		{
			do GOTO_P;
			the_target <- point(pracuje);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** rozrywka agenta **************************************************************
   	    //-----------------------------------------------------------------------------------	---------------------
		reflex dom_rozrywka when: !SEIR_D 
			 and spaceruje != nil and oglada_obrazy != nil  
			 and !SEIR_P and !SEIR_I 				// nie jest pozytywnie zdiagnozowany, ani zakazony
			 and flip(isQuarantine?ogr_rozrywka:1.0)
			 and !_TO_INF_HOSP
			  
		     and (DST_D			// jest w domu 
			 and (
			 	(((time / #days) mod 7) < 5  and ( time  mod (24 * #hour)) = start_rozrywka) // jest dzien tygodnia
			 or (((time / #days) mod 7) >= 5 and ( time  mod (24 * #hour)) = start_weekend_roz)) ) // lub weekend
			 and flip(p_muzeum + p_park)					// 
		{
			do GOTO_R;
			if      (flip(p_muzeum/(p_muzeum + p_park))) 
				{ the_target <- point(oglada_obrazy); }
			else 
				{ the_target <- point(spaceruje); }
				
			do CHANGE_TRV distance: location distance_to the_target; 
		}

		reflex rozywka_dom when: mieszka != nil and DST_R 
				and ((((time / #days) mod 7) < 5 and ( time  mod (24 * #hour)) = end_rozrywka)
				 or (((time / #days) mod 7) >= 5 and ( time  mod (24 * #hour)) = end_weekend_roz))
		{
			do GOTO_D;
			the_target <- point(mieszka);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** kosciol agenta **************************************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex dom_kosciol when: !SEIR_D and !isQuarantine 
								  and !SEIR_P and !SEIR_I 
								  and modliSie != nil and DST_D 
								  and flip(isQuarantine?ogr_kosciol:1.0) 
								  and !_TO_INF_HOSP
								  and (
								  	(((time / #days) mod 7 ) = 6) and 
								    (( time  mod (24 * #hour)) = msze_start[nr_mszy] )
		) {
			do GOTO_K;
			the_target <- point(modliSie);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		reflex kosciol_dom when: !SEIR_D 
					and mieszka != nil 
					and DST_K
					and  (( time  mod (24 * #hour)) = msze_end[nr_mszy])
		{
			do GOTO_D;
			the_target <- point(mieszka);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** zakupy agenta **************************************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex dom_sklep when: !SEIR_D and !SEIR_P and !SEIR_I 
								  and kupuje != nil 
								  and DST_D  
								  and !SEIR_P and !SEIR_I 				// nie jest pozytywnie zdiagnozowany, ani zakazony
								  and flip(isQuarantine?ogr_zakupy:1.0)
								  and !_TO_INF_HOSP
								  and (((time / #days) mod 7 ) < 6) and 
								  (( time  mod (24 * #hour)) =  start_rozrywka) and
								  flip(p_zakupy)  
								  {
			do GOTO_S;
			the_target <- point(kupuje);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		reflex sklep_dom when: !SEIR_D and 
								mieszka != nil and DST_S and  
								 (((time / #days) mod 7 ) < 6) and 
								 (( time  mod (24 * #hour)) = end_rozrywka)
		{
			do GOTO_D;
			the_target <- point(mieszka);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		//--------------------------------------------------------------------------------------------------------
		// *************************** przejscie na kwarantanne (do szpitala) ************************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex na_kwarantanne when: leczySie != nil 
							  // and SEIR_P or SEIR_I /// zmiana 2021-06-16
							  and _TO_INF_HOSP 
							  and !_WENT_TO_INF_HOSP
							   {
			do GOTO_Q;
			_WENT_TO_INF_HOSP <- true;
			the_target <- point(leczySie);
			do CHANGE_TRV distance: location distance_to the_target; 
			
		} 
		reflex wyzdrowial when: DST_Q and !_TO_INF_HOSP and mieszka != nil {
			do GOTO_D;
			the_target <- point(mieszka);
			do CHANGE_TRV distance: location distance_to the_target; 
		}
		
		
				
		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za ruch ********************************************
   	    //--------------------------------------------------------------------------------------------------------
		
		reflex move
		{
			// przesun liste lokalizacji
		///	segments <- nil;
			
			if the_target != nil {
				//path path_followed <- self goto [target:the_target, on:the_graph, return_path:true];
				//segments <- path_followed.segments;
				//loop line over: segments {
				//	float dist <- line.perimeter;
				//}
				
				path_followed <- goto(target:the_target, on:the_graph, return_path:false);
				
				if the_target = location {
					the_target <- nil;
					do TRV_TO_WALK;
					
					if (poza_powiat = 1 and jedziePKP != nil){
						in_train <- true;
					}
				}	
			}
		}
		   		
		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za model SEAIRPD ***********************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex S_E when: SEIR_S and !TRV_C {

   	    	// kontakt z A lub I
   	    	int nb_hosts <- 0;
   	    	float weather_infl <- 1.0;
   	    	float pr_rozsiewania <- 0.0;
   	    	
			if (!in_train) {
			   	// prawdopodobienstwo rozsiania wirusa
	   	    	
	   	    	loop hst over: self neighbors_at(odleglosc_zarazania * 1#m){
					if (hst.SEIR_I){
						pr_rozsiewania <- pr_rozsiewania + 
									(hst._TO_INF_HOSP?pr_inf_in_inf_hosp:1.0) * exp(-inf_distance_factor * (self distance_to hst)/1#m) * beta 
									* ( (hst.the_target != nil) ? 
										(isMaskOutside and hst.nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_rozsiewania_wirusa ) : 1.0) :  // agent podrozuje
										(isMaskInside  and hst.nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_rozsiewania_wirusa ) : 1.0)    // agent dotarl - jest wewnatrz budynku
								  	  );
					}
					if (hst.SEIR_A) {
						pr_rozsiewania <- pr_rozsiewania + exp(-inf_distance_factor * (self distance_to hst)/1#m) * miu 
									* ( (hst.the_target != nil) ? 
										(isMaskOutside and hst.nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_rozsiewania_wirusa ) : 1.0) :  // agent podrozuje
										(isMaskInside  and hst.nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_rozsiewania_wirusa ) : 1.0)    // agent dotarl - jest wewnatrz budynku
								  	  );
					}
				}
			} else if (in_train){ /// in train (and outside the district) the infection rate is simplified 
				pr_rozsiewania <- beta * (
						person count(each.SEIR_I) + 
						person count(each.SEIR_A) + 
						person count(each.SEIR_P) ) / length(person); // probability of infection is proportional to number of infected
			}
			
			float pr_zakaz <- 0.0;
			pr_zakaz <- (the_target != nil) ? 
							  ( isMaskOutside and nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_zakazenia ) : (1.0) ) : 
							  ( isMaskInside  and nosi_maseczke ? ( (1.0 - maska_prawidlowo) * maska_ogr_zakazenia ) : (1.0) ) ;
			
			/* wplyw pogody:
			 * jako srednia temperature przyjalem 10 st C - srednia dla powiatu pruszkowskiego za kwiecien 2020 to 9,46 
			   jako średnia wilgotnosc  przyjalem 50%     - srednia dla powiatu pruszkowskiego za kwiecien 2020 to 51% */ 
		
			weather_infl <- exp((10.0 - current_temp) * 0.0374) 
			              * exp((current_hum - 50.0)  * 0.0185);
			
			if  flip( pr_rozsiewania * pr_zakaz * weather_infl * wsp_osobniczy){
				SEIR_S <- false;
	   	    	SEIR_E <- true;
	   	    	color <- #blue;
	   	    	
	   	    	expose_begin <- time;
	   	    	kiedy_zakazony <- time;
	   	    	gdzie_zakazony <- location;
	   	    	
	   	    	write "exposed;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
			}   	
	    }
	    reflex E_IA when: (SEIR_E and time = (expose_begin + incubation_time) ) {
	    	SEIR_E <- false;
	    	infection_begin <- time;
	    
	    	if flip(ro) { 
	    		SEIR_A <- true;  
	    		integral_A <- integral_A + 1; 
            
	    		color <- #orange;
	    		write "asymptinf;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
	    		
			 
	    	}
	    	else        { // przejscie do Infected 
	    		SEIR_I <- true; // musi zarazac, dlatego bedzie w stanie I
	    		integral_I <- integral_I + 1;
	    		
	    		color <- #red;
	    		write "symptinf;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
	    	
	    		if (flip(pr_go_to_hospI)){
					_TO_INF_HOSP <- true;
					integral_H <- integral_H + 1;  	
					write "symptinf_hospitalized;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
					    			
	    		}
	    	
	    		if flip(eps) { 
	    			// przechodzi do stanu Positively Diagnozed - po okresie diagnose_time
	    			SEIR_ItoP <- true;
	    		}
	    		else if flip(death_I) {
	    			// przechodzi do stanu Dead - po okresie death_time
	    			SEIR_ItoD <- true;
	    			//write "Agent no " + self.id + ", SI " + cycle + ", should die at " + (infection_begin + time_to_death);
	    		}
	    		else {
	    			// przechodzi do stanu Recovered - po kwarantannie
	    			SEIR_ItoR <- true;
	    		}
	    	}
	    }
	    
	    reflex A_R when: (SEIR_A and time = (infection_begin + recovery_time) ) {
	    	SEIR_A <- false;
	    	SEIR_R <- true;
	    	color <- #gray;
	    	write "recovered;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
	    } 
	    
		reflex I_R when: (SEIR_I and SEIR_ItoR and time = (infection_begin + recovery_time) )  {
			SEIR_I <- false;
			SEIR_ItoR <- false;
			SEIR_R <- true;
			color <- #gray;
			_TO_INF_HOSP <- false;
			_WENT_TO_INF_HOSP <- false;
			
			write "recovered;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
		}
		
		reflex I_P when: (SEIR_I and SEIR_ItoP and time = (infection_begin + diagnose_time) )  {
			SEIR_I <- false;
			SEIR_ItoP <- false;
			SEIR_P <- true; 
			
			integral_P <- integral_P + 1; 
            
			color <- #yellow;
			
			diagnose_begin <- time;
			write "posdiag;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
			
			if (!_TO_INF_HOSP) {
				if (flip(pr_go_to_hospP)) {
					_TO_INF_HOSP <- true;
					integral_H <- integral_H + 1;
					write "posdiag_hospitalized;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
				}
			}
			
			if flip(death_P){
				// przejscie do stanu D, po okresie choroby max(time_to_death - diagnose_time;0)
				SEIR_PtoD <- true;
			} else {
				// wyzdrowienie, po przejsciu kwarantanny
				SEIR_PtoR <- true;
			}
		}
		
		reflex I_D when: (SEIR_I and SEIR_ItoD and time  = (infection_begin + time_to_death) )  {
			SEIR_I <- false;
			SEIR_ItoD <- false;
			SEIR_D <- true;
			integral_D <- integral_D + 1; 
			_TO_INF_HOSP <- false;
			_WENT_TO_INF_HOSP <- false;
			
            write "dead;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
		}
	    
	    reflex P_D when: (SEIR_P and SEIR_PtoD and time = (diagnose_begin + max(0, time_to_death - diagnose_time) )){
	    	SEIR_P <- false;
	    	SEIR_PtoD <- false;
	    	SEIR_D <- true;
	    	integral_D <- integral_D + 1; 
	    	_TO_INF_HOSP <- false;
			_WENT_TO_INF_HOSP <- false;
			
	    	write "dead;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
	    }
	    reflex P_R when: (SEIR_P and SEIR_PtoR and time = (diagnose_begin + recovery_time - diagnose_time) ){
	    	SEIR_P <- false;
	    	SEIR_PtoR <- false;
	    	SEIR_R <- true;
	    	color <- #gray;
	    	_TO_INF_HOSP <- false;
			_WENT_TO_INF_HOSP <- false;
			
	    	write "recovered;" + self.id + ";" + location.x + ";" + location.y + ";" + time + ";" + self.sex + ";" +  self.age;
	    }
	}
}


experiment main_experiment until: (cycle <= 8065)
{
	parameter "Cykl poczatkowy" var: starting_cycle category: "Date";
	
	
	parameter "Ile ludzi" var: person_num category: "People" min: 0 max: 1000000;
	parameter "Ile zarazonych objawowo na poczatku" var: sympt_inf category: "People" min: 0 max: 1000000;
	parameter "Ile zarazonych bezobjawowo na poczatku" var: asympt_inf category: "People" min: 0 max: 1000000;
	parameter "Ile zarazonych wystawionych na poczatku" var: exposed category: "People" min: 0 max: 1000000;
	parameter "Ile ozdrowiencow na poczatku" var: removed category: "People" min: 0 max: 1000000;
	parameter "Ile potwierdzonych na poczatku" var: posdiag category: "People" min: 0 max: 1000000;
	parameter "Ile zmarlo na poczatku" var: dead category: "People" min: 0 max: 1000000;
	parameter "Ile osob odpornych na poczatku" var: immune category: "People" min: 0 max: 1000000;
	
	
	parameter "Folder z mapami" var: model_folder category: "Settings";
	parameter "Plik wyjsciowy csv" var: csv_file_name category: "Settings";
	parameter "Strigency policy file" var: strig_file category: "Settings";
	parameter "Vaccination policy file" var: vacpol_file category: "Settings";
	
	parameter "religijnosc" var: p_modliSie category: "Powiat";
	
	
	
	parameter "Czy jest kwarantanna" var: isQuarantine category: "Kwarantanna";
	parameter "Ograniczenia chodzenia do szkoly podczas kwarantanny" var: base_ogr_szkoly category: "Kwarantanna";
	parameter "Ograniczenia chodzenia na zakupy podczas kwarantanny" var: base_ogr_zakupy category: "Kwarantanna";
	parameter "Ograniczenia rozrywania sie podczas kwarantanny" var: base_ogr_rozrywka category: "Kwarantanna";
	parameter "Ograniczenia chodzenia do lekarza podczas kwarantanny" var: base_ogr_leczenie category: "Kwarantanna";
	parameter "Ograniczenia chodzenia do kosciola podczas kwarantanny" var: base_ogr_kosciol category: "Kwarantanna";
	parameter "Ograniczenie w chodzeniu do pracy - podstawowe" var: base_ogr_pracy category: "Kwarantanna";
	parameter "Ograniczenie w chodzeniu do pracy w I kwartale 2020" var: ogr_pracyIkw2020 category: "Kwarantanna";
	parameter "Ograniczenie w chodzeniu do pracy w II kwartale 2020" var: ogr_pracyIIkw2020 category: "Kwarantanna";
	parameter "Ograniczenie w chodzeniu do pracy w III kwartale 2020" var: ogr_pracyIIIkw2020 category: "Kwarantanna";
	parameter "Ograniczenie w chodzeniu do pracy w IV kwartale 2020" var: ogr_pracyIVkw2020 category: "Kwarantanna";
	
	parameter "Strigency index" var: use_strigency_index category: "Kwarantanna";
	parameter "Vaccination policy" var: use_vaccinations category: "Kwarantanna";
		
	parameter "Czy wymagana jest maseczka wewnatrz budynkow" var: isMaskInside category: "Maseczka";
	parameter "Czy wymagana jest maseczka poza budynkami" var: isMaskOutside category: "Maseczka";
	parameter "Ograniczenie rozsiewania wirusa przy zalozonej maseczce" var: maska_ogr_rozsiewania_wirusa category: "Maseczka";
	parameter "Ograniczenie zakazenia sie przy zalozonej maseczce" var: maska_ogr_zakazenia category: "Maseczka";
	parameter "Prawdopodobienstwo ze maseczka jest zalozona prawidlowo" var: maska_prawidlowo category: "Maseczka";
	parameter "Procent osob noszacych maseczke prawidlowo" var: base_pr_nosi_maske category: "Maseczka";
	
	parameter "Udzial zakazonych bezobjawowo" var: ro category: "COVID-19" min: 0.0 max: 1.0;
	parameter "Wskaznik smiertelnosci osob hospitalizowanych"    var: dI category: "COVID-19" min: 0.0 max: 1.0;
	parameter "Wskaznik smiertelnosci osob z objawami zakazenia" var: dP category: "COVID-19" min: 0.0 max: 1.0;
	parameter "Wspolczynnik zakaznosci przy kontakcie z zakazonym objawowo" var: beta category: "COVID-19" min: 0.0 max: 1.0;
	parameter "Wspolczynnik zakaznosci przy kontakcie z zakazonym bezobjawowo" var: miu category: "COVID-19" min: 0.0 max: 1.0;

	parameter "Odleglosc zarazania" var: odleglosc_zarazania category: "COVID-19" min: 0 max: 1000;
	parameter "Wspolczynnik zarazania" var: inf_distance_factor category: "COVID-19" min: 0.0 max: 1000.0;
	
//	reflex garbage_collector when: every(1 #days) {
//		do compact_memory();
		//System.gc();
//	}
		
	output
	{
		
		display miasto type: opengl ambient_light: 100
		{
			species budynki aspect: base;
			species miejsca_pracy aspect: base;
			species person aspect: base;
			species drogi aspect: base;
			species szkoly aspect: base;
			species zdrowie aspect: base;
			species stacje_pkp aspect: base;
			species koscioly aspect: base;
			species muzea aspect: base;
			species sklepy aspect: base;
			species parki aspect: base;
//			species person aspect: icon;
		}
		
		display chart refresh: every(10#cycles) {
				chart "Plot" type: series background: #lightgray style: exploded {
		//		data "susceptible" value: person count (each.S) color: #green;
				data "Immune" value: person count (each.SEIR_IV) color: #green;  
				data "Exposed" value: person count (each.SEIR_E) color: #blue;
				data "Asymptotically infected" value: person count (each.SEIR_A) color: #orange;
				data "Symptotically infected" value: person count (each.SEIR_I) color: #red;
				data "Positively diagnozed" value: person count (each.SEIR_P) color: #purple;
				data "Recovered" value: person count (each.SEIR_R) color: #cyan;
				data "Dead" value: person count (each.SEIR_D) color: #black;
				data "Total infections" value: person count (each.gdzie_zakazony != nil) color: #magenta;
			}
		}
		
		monitor "Susceptible" name: num_S value: person count(each.SEIR_S);
		monitor "Immune" name: num_IV value: person count(each.SEIR_IV);
		monitor "Exposed" name: num_E value: person count(each.SEIR_E);
		monitor "SymptoticalyInfected"  name: num_I value: person count(each.SEIR_I);
		monitor "AsyptomaticalyInfected" name: num_A value: person count(each.SEIR_A);
		monitor "Recovered" name: num_R value: person count(each.SEIR_R);		
		monitor "PositivelyDiagnozed" name: num_P value: person count(each.SEIR_P);
		monitor "Dead" name: num_D value: person count(each.SEIR_D);
		monitor "Hospitalized" name: num_H value: person count(each._TO_INF_HOSP);
		monitor "Infections" name: num_Infections value: person count(each.gdzie_zakazony != nil);
		monitor "TotalSymptoticalyInfected" name: int_I value: integral_I;
		monitor "TotalAsymptoticalyInfected" name: int_A value: integral_A;
		monitor "TotalPositivelyDiagnozed" name: int_P value: integral_P;
		monitor "TotalHospitalized" name: int_H value: integral_H;
		monitor "TotalDead" name: int_D value: integral_D;
		monitor "CurrentDate" name: dat value: current_date;		
	}
}
