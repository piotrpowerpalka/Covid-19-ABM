/**
 *  COVID-19
 *  Author: Piotr Palka
 *  Description:  
 */
model COVID

global
{
    int person_num <- 1000;
    int sympt_inf <- 1;
    int asympt_inf <- 1;
    	
	/*	COVID-19 ver_3 */
	file shape_file_budynki <- file("../includes/MM/OBIEKTY_region.shp");
	file shape_file_drogi <- file("../includes/MM/drogi_polyline.shp");
	file shape_file_granice <- file("../includes/MM/heksy_region.shp");
	file shape_file_hexy <- file("../includes/MM/heksy_region.shp");
	file shape_file_agenty <- file ("../includes/MM/MIESZKANCY_MM_point.shp");
	
	geometry shape <- envelope(shape_file_granice);
	
	float step <- 15 #mn;
	float incubation_time <- 3 #days / step;
	float recovery_time <- 14 #days  / step;
	float diagnose_time <- 3 #days  / step;
	
	
	// do weryfikacji i nauczenias
	float ro <- 0.85;
	float dI <- 0.01356770 * 10; 
	float dP <- 0.0041681711 * 10;
	float eps <- 0.5; // TODO!!!!
	float beta <- 0.0005965935 / 2; // trzeba podzielić tak, żeby odpowiadało za pr/dobę
	float miu <- 0.0005965935 / 2;	// trzeba podzielić tak, żeby odpowiadało za pr/dobę
	
	int current_hour update: (time / #hour) mod 24;
	int current_day update: (time / #days) mod 7;
	
	int min_work_start <- 0;
	int max_work_start <- 2;
	int min_work_end <- 16;
	int max_work_end <- 18;

	int min_rozrywka_start <- 18;
	int max_rozrywka_start <- 20;
	int min_rozrywka_end <- 21;
	int max_rozrywka_end <- 23;

	int min_lekarz_start <- 8;
	int max_lekarz_start <- 10;
	int min_lekarz_end <- 11;
	int max_lekarz_end <- 13;

	float is_rozrywka <- 0.5;
	
	// do sprawdzenia
	float proc_robotnikow <- 0.35;
	float proc_lekarzy <- 0.05;
	float proc_nauczycieli <- 0.1;
	
	float proc_blokersow <- 0.8;
	float probChangeParamOnLoc <- 0.1;

	float pojdzie_do_lekarza <- 0.15;
	
	float min_speed <- 3.0 # km / # h;
	float max_speed <- 5.0 # km / # h;
	graph the_graph;

	list<budynki> kultura;
	list<budynki> domki;
	list<budynki> bloki;
	
	int number_S <- 0;
	int number_E <- 0;
	int number_I <- 0;
	int number_A <- 0;
	int number_R <- 0;
	int number_P <- 0;
	int number_D <- 0;
	
	
	bool isQuarantine <- false;
	bool isMaskInside <- false;
	bool isMaskOutside <- false;
	
	
	reflex aff when: cycle mod 10 = 0 {
		write "Message at cycle " + cycle ;	
	}
	
	init
	{	
		create budynki from: shape_file_budynki with: [type:: string(read("TYP"))]
		{
			height <- 1;
			if type = "domki"	//+
			{
				color <- rgb(255, 208, 160);
				lcolor <- # black;
			} else if type = "blokowisko"	//+
			{
				color <- rgb(255, 0, 0);
				lcolor <- # black;
			} else if type = "biurowiec"	//+
			{
				color <- rgb(220, 128, 128);
				lcolor <- # black;
			} else if type = "fabryka"	//+
			{
				color <- rgb(208, 208, 208);
				lcolor <- # black;
			} else if type = "zabytki"	//+
			{
				color <- rgb(140, 140, 140);
				lcolor <- # black;
				height <- 2;
			} else if type = "uslugi"	//+
			{
				color <- rgb(240, 255, 0);
				lcolor <- # black;
			} else if type = "rzeka"	//+
			{
				color <- rgb(96, 203, 255);
				lcolor <- rgb(96, 203, 255);
				height <- 1;
			} else if type = "park"		//+
			{
				color <- rgb(0, 208, 0);
				lcolor <- rgb(0, 208, 0);
				height <- 1;
			} else if type = "szkoly"	//+	
			{
				color <- rgb(70, 210, 70);
				lcolor <- # black;
				height <- 2;
			} else if type = "zdrowie"	//+
			{
				color <- rgb(110, 110, 220);
				lcolor <- # black;
				height <- 2;
				
			} else if type = "bulwary"	//+
			{
				color <- rgb(211, 255, 144);
				lcolor <- rgb(211, 255, 144);
				
			} else if type = "kultura"{
				color <- rgb(255, 140, 0);
				lcolor <- # black;
				height <- 2;
			}
		}

		list<budynki> biura <- budynki where (each.type = "biurowiec" or each.type = "szkoly");
		list<budynki> fabryki <- budynki where (each.type = "fabryka");
		list<budynki> przychodnie <- budynki where (each.type = "zdrowie");
		domki <- budynki where (each.type = "domki");
		bloki <- budynki where (each.type = "blokowisko");		
		kultura <- budynki where (each.type = "zabytki" or each.type = "park" or each.type = "bulwary");

		create drogi from: shape_file_drogi with: [id::int(read("ID")), typ::string(read("TYP"))];
		the_graph <- as_edge_graph(drogi);
		int idd <- 0;
		
		create person number: (person_num - asympt_inf - sympt_inf) {
			objective <- "D";
			speed <- min_speed + rnd(max_speed - min_speed) # km / # h;

			start_work <- min_work_start + rnd((max_work_start - min_work_start) * 60) / 60;
			end_work <- min_work_end + rnd((max_work_end - min_work_end) * 60) / 60;

			start_rozrywka <- flip(is_rozrywka) ? min_rozrywka_start + rnd((max_rozrywka_start - min_rozrywka_start) * 60) / 60 : -1;
			end_rozrywka <- min_rozrywka_end + rnd((max_rozrywka_end - min_rozrywka_end) * 60) / 60;

			start_lekarz <- min_lekarz_start + rnd((max_lekarz_start - min_lekarz_start) * 60) / 60;
			end_lekarz <- min_lekarz_end + rnd((max_lekarz_end - min_lekarz_end) * 60) / 60;
			
			if flip(proc_robotnikow)   { pracuje <- one_of(fabryki); }
			else if flip(proc_lekarzy) { pracuje <- one_of(przychodnie); }
			// else if flip(proc_nauczycieli) pracuje <- one_of(szkola);
			else { pracuje <- one_of(biura); } 

			rozrywasie <- one_of(kultura);
			leczySie <- one_of(przychodnie);
			mieszka <- one_of(domki);
			location <- any_location_in(mieszka);
			loc <- list_with(2, location);
			
			S <- true;
        	E <-  false;
            I <-  false; 
            A <-  false; 
            R <-  false; 
            P <-  false; 
            color <- #green;
            
            id <- idd;
            idd <- idd + 1;  				
		}
		create person number: asympt_inf {
			objective <- "D";
			speed <- min_speed + rnd(max_speed - min_speed) # km / # h;
			start_work <- min_work_start + rnd((max_work_start - min_work_start) * 60) / 60;
			end_work <- min_work_end + rnd((max_work_end - min_work_end) * 60) / 60;
			start_rozrywka <- flip(is_rozrywka) ? min_rozrywka_start + rnd((max_rozrywka_start - min_rozrywka_start) * 60) / 60 : -1;
			end_rozrywka <- min_rozrywka_end + rnd((max_rozrywka_end - min_rozrywka_end) * 60) / 60;
			start_lekarz <- min_lekarz_start + rnd((max_lekarz_start - min_lekarz_start) * 60) / 60;
			end_lekarz <- min_lekarz_end + rnd((max_lekarz_end - min_lekarz_end) * 60) / 60;
			
			if flip(proc_robotnikow)   { pracuje <- one_of(fabryki); }
			else if flip(proc_lekarzy) { pracuje <- one_of(przychodnie); }
			// else if flip(proc_nauczycieli) pracuje <- one_of(szkola);
			else { pracuje <- one_of(biura); } 

			rozrywasie <- one_of(kultura);
			leczySie <- one_of(przychodnie);
			mieszka <- one_of(domki);
			location <- any_location_in(mieszka);
			loc <- list_with(2, location);
			
			S <- false;
        	E <-  false;
            I <-  false; 
            A <-  true; 
            R <-  false; 
            P <-  false; 
            color <- #orange;  		
            id <- idd;
            idd <- idd + 1;
        
            infection_begin <- cycle;      				
		}
		
		create person number: sympt_inf {
			objective <- "D";
			speed <- min_speed + rnd(max_speed - min_speed) # km / # h;
			start_work <- min_work_start + rnd((max_work_start - min_work_start) * 60) / 60;
			end_work <- min_work_end + rnd((max_work_end - min_work_end) * 60) / 60;
			start_rozrywka <- flip(is_rozrywka) ? min_rozrywka_start + rnd((max_rozrywka_start - min_rozrywka_start) * 60) / 60 : -1;
			end_rozrywka <- min_rozrywka_end + rnd((max_rozrywka_end - min_rozrywka_end) * 60) / 60;
			start_lekarz <- min_lekarz_start + rnd((max_lekarz_start - min_lekarz_start) * 60) / 60;
			end_lekarz <- min_lekarz_end + rnd((max_lekarz_end - min_lekarz_end) * 60) / 60;
			
			if flip(proc_robotnikow)   { pracuje <- one_of(fabryki); }
			else if flip(proc_lekarzy) { pracuje <- one_of(przychodnie); }
			// else if flip(proc_nauczycieli) pracuje <- one_of(szkola);
			else { pracuje <- one_of(biura); } 
			
			rozrywasie <- one_of(kultura);
			leczySie <- one_of(przychodnie);
			mieszka <- one_of(domki);
			location <- any_location_in(mieszka);
			loc <- list_with(2, location);
			
			S <- false;
        	E <-  false;
            I <-  true; 
            A <-  false; 
            R <-  false; 
            P <-  false; 
            color <- #red;
            
            id <- idd;
            idd <- idd + 1;
            
            infection_begin <- cycle;
            
            //TODO: sprawdzić czy to samo co poniżej
 			if flip(eps) { 
    			// przechodzi do stanu Positively Diagnozed - po okresie diagnose_time
    			ItoP <- true;
    		}
    		else if flip(dI) {
    			// przechodzi do stanu Dead - po okresie death_time
    			ItoD <- true;
    			write "Agent no " + self.id + ", SI " + cycle + ", should die at " + (infection_begin + time_to_death);
    		}
    		else {
    			// przechodzi do stanu Recovered - po kwarantannie
    			ItoR <- true;
    		}
      		  				
		}	
	}
	
	
	species budynki
	{
		string type;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		int height;
		aspect base { draw shape color: color border: lcolor depth: height; }
	}

	species drogi
	{ 
		int id;
		string typ;
		rgb color <- rgb(0, 0, 0);
		int height <- 0;
		aspect base { draw shape color: color; }
	}
	
	species	person skills: [moving] parallel: true 
	{
		// kolejne stany modelu 
		bool S <- true;  // Susceptible
		bool E <- false; // Exposed
    	bool I <- false; // Symptomatic (I)nfected
    	bool A <- false; // (A)symptomatic Infected
    	bool P <- false; // (P)ositively Diagnozed
    	bool D <- false; // Dead - nie wystąpi, agent umiera
    	bool R <- false; // Removed/recovered
    	
    	bool ItoP <- false; // stan gdy jest już zadecydowano o przejściu do stanu P, ale agent wciąż jest w stanie I
    	bool ItoD <- false; // stan gdy jest już zadecydowano o przejściu do stanu D, ale agent wciąż jest w stanie I
    	bool ItoR <- false; // stan gdy jest już zadecydowano o przejściu do stanu R, ale agent wciąż jest w stanie I
    	bool PtoD <- false; // stan gdy jest już zadecydowano o przejściu do stanu D, ale agent wciąż jest w stanie P
    	bool PtoR <- false; // stan gdy jest już zadecydowano o przejściu do stanu R, ale agent wciąż jest w stanie P
    	
    	// do poprawienia
    	float time_to_death <- rnd(3,14,1) * (1 #days) / step; // czas od zarażenia do śmierci I->D: CHECK
    	
    	float infection_begin <- -1;
    	float diagnose_begin <- -1;
    	float expose_begin <- -1; 
    
		int id;
		float speed;
		rgb color;
		budynki mieszka;	
		budynki pracuje;
		budynki urzeduje;
		budynki rozrywasie;
		budynki leczySie;
		
		int start_work;
		int end_work;
		int start_rozrywka;
		int end_rozrywka;
		int start_urzad;
		int end_urzad;
		int start_lekarz;
		int end_lekarz;
		bool isMarried;
		int numOfChildren;
		
		string objective;
		point the_target;
		
		
		float age min: 0.0 max: 1.0;
		string sex;
		int morbidity;
		
		list<point> loc <- nil;
			
		aspect base { 
			if A or I {
				draw convex_hull(circle(2#m, loc[0]) + circle(2#m, loc[1])) color: color;
			} else {
				draw circle(0.5#m) color: color;				
			}
		}

		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za rytm życia agenta *******************************
   	    //--------------------------------------------------------------------------------------------------------

		reflex dom_praca when: !D and !isQuarantine and !P and !I 
								and pracuje != nil and current_hour = start_work and objective = "D" and current_day < 5  {
			objective <- "P";
			the_target <- point(pracuje);
		}
		
		reflex praca_dom when: mieszka != nil and current_hour = end_work and objective = "P"
		{
			objective <- "D";
			the_target <- point(mieszka);
		}
		
		reflex praca_lekarz  when: leczySie != nil and objective = "P" and flip(pojdzie_do_lekarza) and current_hour = start_lekarz
		{
			objective <- "L";
			the_target <- point(leczySie);
		}

		reflex lekarz_praca when: pracuje != nil and objective = "L" and current_hour = end_lekarz
		{
			objective <- "P";
			the_target <- point(pracuje);
		}
		
		reflex dom_rozrywka when: !D and !isQuarantine and !P and !I 
								  and (rozrywasie != nil and objective = "D" and ((current_day < 5 and current_hour = start_rozrywka)
								  or (current_day > 4 and current_hour > 9)) )
		{
			objective <- "R";
			the_target <- point(rozrywasie);
		}

		reflex rozywka_dom when: mieszka != nil and objective = "R" and ((current_day < 5 and current_hour = end_rozrywka)
										  or (current_day > 4 and current_hour > 21))
		{
			objective <- "D";
			the_target <- point(mieszka); 
		}
		
		reflex na_kwarantanne when: P or I {
			objective <- "Q";
			the_target <- point(leczySie);
		} 
		
		reflex wyzdrowial when: objective = "Q" and R {
			objective <- "D";
			the_target <- point(mieszka);
		}
				
		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za ruch ********************************************
   	    //--------------------------------------------------------------------------------------------------------
		
		reflex move when: the_target != nil
		{
			// przesun liste lokalizacji
			loc[1] <- loc[0];
			loc[0] <- location;
			
			path path_followed <- self goto [target:the_target, on:the_graph, return_path:true];
			list<geometry> segments <- path_followed.segments;
			loop line over: segments {
				float dist <- line.perimeter;
			}
			if the_target = location {
				the_target <- nil;
				location <- { location.x, location.y };
			}
		}
		   		
		//--------------------------------------------------------------------------------------------------------
		// *************************** reflexy odpowiedzialne za model SEAIRPD ***********************************
   	    //--------------------------------------------------------------------------------------------------------
		reflex S_E when: S {
   	    	// warunki do zarazenia TODO
   	    	// kontakt z A lub I
   	    	int nb_hosts <- 0;
   	    	int nb_hosts_infected <- 0;
   	    	int nb_hosts_ainfected <- 0;
   	    	
   	    	loop hst over: (person at_distance 2#m) {
    			if (hst.I) {nb_hosts_infected <- nb_hosts_infected + 1;}
    			if (hst.A) {nb_hosts_ainfected <- nb_hosts_ainfected + 1;}
    			
    		}
			float pr_inf <- nb_hosts_infected * beta + nb_hosts_ainfected * miu;
			if  flip(pr_inf){
				S <- false;
	   	    	E <- true;
	   	    	color <- #blue;
	   	    	expose_begin <- cycle;
			}   	
	    }
	    reflex E_IA when: (E and cycle = (expose_begin + incubation_time) ) {
	    	E <- false;
	    	infection_begin <- cycle;
	    
	    	if flip(ro) { 
	    		A <- true;  
	    		color <- #orange; 
	    	}
	    	else        { // przejście do Infected 
	    		I <- true; // musi zarażać, dlatego będzie w stanie I
	    		color <- #red;
	    		
	    		if flip(eps) { 
	    			// przechodzi do stanu Positively Diagnozed - po okresie diagnose_time
	    			ItoP <- true;
	    		}
	    		else if flip(dI) {
	    			// przechodzi do stanu Dead - po okresie death_time
	    			ItoD <- true;
	    			write "Agent no " + self.id + ", SI " + cycle + ", should die at " + (infection_begin + time_to_death);
	    		}
	    		else {
	    			// przechodzi do stanu Recovered - po kwarantannie
	    			ItoR <- true;
	    		}
	    	}
	    }
	    
	    reflex A_R when: (A and cycle = (infection_begin + recovery_time) ) {
	    	A <- false;
	    	R <- true;
	    	color <- #gray;
	    	
	    	
	    } 
	    
		reflex I_R when: (I and ItoR and cycle = (infection_begin + recovery_time) )  {
			I <- false;
			ItoR <- false;
			R <- true;
			color <- #gray;
		}
		
		reflex I_P when: (I and ItoP and cycle = (infection_begin + diagnose_time) )  {
			I <- false;
			ItoP <- false;
			P <- true; // TODO: napisać żeby po przejściu do P przeszli na kwarantannę
			color <- #yellow;
			
			diagnose_begin <- cycle;
			
			if flip(dP){
				// przejście do stanu D, po okresie choroby max(time_to_death - diagnose_time;0)
				PtoD <- true;
				write "Agent no " + self.id + ", P " + cycle + ", should die at " + (diagnose_begin + max(0, time_to_death - diagnose_time) );
				
			} else {
				// wyzdrowienie, po przejsciu kwarantanny
				PtoR <- true;
			}
		}
		
		reflex I_D when: (I and ItoD and cycle = (infection_begin + time_to_death) )  {
			I <- false;
			ItoD <- false;
			D <- true;
	    	write "Agent no " + self.id + ", dead at " + cycle + ", was symptomatically infected";
		}
	    
	    reflex P_D when: (P and PtoD and cycle = (diagnose_begin + max(0, time_to_death - diagnose_time) )){
	    	P <- false;
	    	PtoD <- false;
	    	D <- true;
	    	write "Agent no " + self.id + ", dead at " + cycle + ", was positively diagnozed ";
	    }
	    reflex P_R when: (P and PtoR and cycle = (diagnose_begin + recovery_time - diagnose_time) ){
	    	P <- false;
	    	PtoR <- false;
	    	R <- true;
	    	color <- #gray;
	    }
	}
	
}


experiment main_experiment  type: gui until: (time > 1 # d)
{
	parameter "Ile ludzi" var: person_num category: "People" min: 0.0 max: 1000000.0;
	
	parameter "Prawdopodobienstwo ze sie rozerwie" var: is_rozrywka category: "People" min: 0.0 max: 1.0;
	parameter "Prawdopodobienstwo ze pojdzie do lekarza" var: pojdzie_do_lekarza category: "People" min: 0.0 max: 1.0;
	parameter "Prawdopodobienstwo zmiany parametru w lokalizacji" var: probChangeParamOnLoc category: "Model" min: 0.0 max: 1.0;
	
	parameter "SHP dla mieszkan:" var: shape_file_budynki category: "GIS";
	parameter "SHP dla drog:" var: shape_file_drogi category: "GIS";
	parameter "SHP dla granic:" var: shape_file_granice category: "GIS";
	parameter "SHP dla hexow:" var: shape_file_hexy category: "GIS";
	
		
	output
	{
		display miasto type: opengl ambient_light: 100
		{
			species budynki aspect: base;
			species drogi aspect: base;
			species person aspect: base;
		}
		display chart refresh: every(10#cycles) {
				chart "Plot" type: series background: #lightgray style: exploded {
		//		data "susceptible" value: person count (each.S) color: #green;
				data "exposed" value: person count (each.E) color: #blue;
				data "asymptotically infected" value: person count (each.A) color: #orange;
				data "symptotically infected" value: person count (each.I) color: #red;
				data "Positively diagnozed" value: person count (each.P) color: #purple;
				data "Recovered" value: person count (each.R) color: #cyan;
				data "Dead" value: person count (each.D) color: #black;
			}
		}
		monitor "Susceptible" name: num_S value: person count(each.S);
		monitor "Sum exposed" name: num_E value: person count(each.E);
		monitor "Sum I"  name: num_I value: person count(each.I);
		monitor "Sum A" name: num_A value: person count(each.A);
		monitor "Sum R" name: num_R value: person count(each.R);		
		monitor "Sum P" name: num_P value: person count(each.P);
		monitor "Sum D" name: num_D value: person count(each.D);
	}
}