/**
 *  COVID-19
 *  Author: Piotr Palka
 *  Description:  
 */
model COVID


global
{
	//Number of susceptible host at init
    int number_S <- 0;
    //Number of infected host at init
    int number_I <- 0 ;
    //Number of resistant host at init
    int number_R <- 0 ;
    
    // zakładany promień rozprzestrzeniania się wirusa
    float infection_radius <- 5.0#m;
    
    // zakładany czas przezycia wirusa 
    // na razie godzina
	
	float beta <- 0.05 ;
	//Mortality rate for the host 
	
	float nu <- 0.001 ;
	//Rate for resistance 
	
	float delta <- 0.01;
	//Number total of hosts

	//Range of the cells considered as neighbours for a cell
	int neighbours_size <- 2 min:1 max: 5 parameter:"Size of the neighbours";
	
	
	/*	COVID-19 ver_1 */
	file shape_file_budynki <- file("../includes/MM/OBIEKTY_region.shp");
	file shape_file_drogi <- file("../includes/MM/drogi_polyline.shp");
	file shape_file_granice <- file("../includes/MM/heksy_region.shp");
	file shape_file_hexy <- file("../includes/MM/heksy_region.shp");
	file shape_file_agenty <- file ("../includes/MM/MIESZKANCY_MM_point.shp");
	
	geometry shape <- envelope(shape_file_granice);
	bool rysujLudziki <- false;
	bool saveToCSV <- false;
	string outputFile <- "output.csv";
	bool _3Dcity <- true;
	float step <- 5 # mn;
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
	int min_urzad_start <- 10;
	int max_urzad_start <- 12;
	int min_urzad_end <- 13;
	int max_urzad_end <- 15;
	int min_lekarz_start <- 8;
	int max_lekarz_start <- 10;
	int min_lekarz_end <- 11;
	int max_lekarz_end <- 13;
	float is_rozrywka <- 0.5;
	float proc_robotnikow <- 0.5;
	float proc_blokersow <- 0.8;
	float probChangeParamOnLoc <- 0.1;
	float pojdzie_do_urzedu <- 0.25;
	float pojdzie_do_lekarza <- 0.15;
	
	float min_speed <- 3.0 # km / # h;
	float max_speed <- 5.0 # km / # h;
	graph the_graph;

	list<budynki> kultura;
	list<budynki> urzedy;
	list<heksy> hexy;
	list<budynki> domki;
	list<budynki> bloki;
	
	reflex aff {
		write "Message at cycle " + cycle ;
		write "Number of infections " + person count(each.is_infected);
		write "Number of susceptible " + person count(each.is_susceptible);
	}
	
	init
	{	
		create heksy from: shape_file_hexy with: [id::int(read("ID")), nazwa::string(read("NAZWA")),ludnosc::int(read("LUDNOSC")),
			LM::int(read("LL")),typ::string(read("TYP"))
		];
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

			if (!_3Dcity)
			{
				lcolor <- color;
				height <- 0;
			}

		}

		

		list<budynki> biura <- budynki where (each.type = "biurowiec" or each.type = "szkoly");
		list<budynki> fabryki <- budynki where (each.type = "fabryka");
		list<budynki> przychodnie <- budynki where (each.type = "zdrowie");
		domki <- budynki where (each.type = "domki");
		bloki <- budynki where (each.type = "blokowisko");		
		kultura <- budynki where (each.type = "zabytki" or each.type = "park" or each.type = "bulwary");
		urzedy <- budynki where (each.type = "urzad");
		hexy <- heksy;

		create drogi from: shape_file_drogi with: [id::int(read("ID")), typ::string(read("TYP")), Liczbajezd::int(read("Liczbajezd"))];
		the_graph <- as_edge_graph(drogi);
		
		/* Tworzenie agentow poprzez pobieranie danych z pliku */
		create person from: shape_file_agenty with: [id::int(read("ID")), age::float(read("AGE")), trustToPeople::float(read("PEOPLE")),
			trustToInstitutios::float(read("INST")), altruism::float(read("ALTRUISM")), education::float(read("EDUCATION")),
			happiness::float(read("HAPPINESS")), wealth::float(read("WEALTH")), identity::float(read("IDENTITY")),
			isMarried::int(read("MARRIED")), numOfChildren::int(read("CHILDREN")) 
		]{
			objective <- "w_domu";
			speed <- min_speed + rnd(max_speed - min_speed) # km / # h;
			start_work <- min_work_start + rnd((max_work_start - min_work_start) * 60) / 60;
			end_work <- min_work_end + rnd((max_work_end - min_work_end) * 60) / 60;
			start_rozrywka <- flip(is_rozrywka) ? min_rozrywka_start + rnd((max_rozrywka_start - min_rozrywka_start) * 60) / 60 : -1;
			end_rozrywka <- min_rozrywka_end + rnd((max_rozrywka_end - min_rozrywka_end) * 60) / 60;
			start_urzad <- min_urzad_start + rnd((max_urzad_start - min_urzad_start) * 60) / 60;
			end_urzad <- min_urzad_end + rnd((max_urzad_end - min_urzad_end) * 60) / 60;
			start_lekarz <- min_lekarz_start + rnd((max_lekarz_start - min_lekarz_start) * 60) / 60;
			end_lekarz <- min_lekarz_end + rnd((max_lekarz_end - min_lekarz_end) * 60) / 60;
			
			pracuje <- flip(proc_robotnikow) ? one_of(fabryki) : one_of(biura);
			urzeduje <- one_of(urzedy);
			rozrywasie <- one_of(kultura);
			leczySie <- one_of(przychodnie);
			mieszka <- budynki closest_to(location);
			mojHex <- heksy closest_to(location);
			
			is_susceptible <- true;
        	is_infected <-  false;
            is_immune <-  false; 
            number_S <- number_S + 1; 
			color <-  #green;
            
			
			if (flip(0.01)){
				is_susceptible <- false;
            	is_infected <-  true;
            	is_immune <-  false; 
            	color <-  #red;
            	number_S <- number_S - 1;
       			number_I <- number_I + 1;
            } 
      		if (flip(0.01)) {
      	      	is_susceptible <-  false;
        	    is_infected <-  false;
            	is_immune <-  true; 
            	color <-  #blue;
            	number_S <- number_S - 1;
       			number_R <- number_R + 1;
            	
			}
			loc <- list_with(15, mieszka);			
		}	
		
		
		
	
	}
	
	species slad 
	{
		person rodzic <- nil;
		geometry zasieg <- nil;
		int numer <- -1;
		point p1;
		point p2;
		
		aspect base{
			draw zasieg color: #orange border: #black; 
		}
		
		reflex przesun when: rodzic != nil {
			p2 <- p1;
			p1 <- rodzic.loc[numer];
			zasieg <- convex_hull(circle(infection_radius, p1) + circle(infection_radius, p2));
		}
	}
	
	species heksy
	{
		int id;
		string nazwa;
		int ludnosc;
		int LM;
		string typ;
		aspect base
		{
			draw shape color: # transparent border: # black;
		}
	}

	species budynki
	{
		string type;
		rgb color <- # gray;
		rgb lcolor <- # gray;
		int height;
		aspect base
		{
			draw shape color: color border: lcolor depth: height;
		}

	}

	species drogi
	{ 
		int id;
		string typ;
		int Liczbajezd;
		rgb color <- rgb(0, 0, 0);
		int height <- 3;
		aspect base
		{
			draw shape color: color;
		}

	}
	
	species	person skills: [moving] 
	{
		bool is_susceptible <- true;
		bool is_infected <- false;
    	bool is_immune <- false;
    	int infection_begin <- -1; 
    
		int id;
		float speed;
		rgb color;
		budynki mieszka;	
		budynki pracuje;
		budynki urzeduje;
		budynki rozrywasie;
		budynki leczySie;
		heksy mojHex;
		int start_work;
		int end_work;
		int start_rozrywka;
		int end_rozrywka;
		int start_urzad;
		int end_urzad;
		int start_lekarz;
		int end_lekarz;
		string objective;
		point the_target;
		bool isMarried;
		int numOfChildren;
		float age min: 0.0 max: 1.0;
		float trustToPeople min: 0.0 max: 1.0;
		float trustToInstitutios min: 0.0 max: 1.0;
		float altruism min: 0.0 max: 1.0;
		float education min: 0.0 max: 1.0;
		float happiness min: 0.0 max: 1.0;
		float wealth min: 0.0 max: 1.0;
		float identity min: 0.0 max: 1.0;
		
		// slad
		list<point> loc <- nil;
		int ile_sladow <- 0;
		
		//Count of neighbors infected 
    	//int ngb_infected_number function: {self neighbors_at(neighbours_size) count(each.is_infected)};
	
		
		aspect base
		{
			draw circle(infection_radius) color: color;
		}

		reflex dom_praca when: pracuje != nil and current_hour = start_work and objective = "w_domu" and current_day < 5
		{
			objective <- "pracuje";
			the_target <- point(pracuje);
		}
		reflex praca_dom when: mieszka != nil and current_hour = end_work and objective = "pracuje"
		{
			objective <- "w_domu";
			the_target <- point(mieszka);
		}
		reflex praca_urzad when: urzeduje != nil and objective = "pracuje" and flip(pojdzie_do_urzedu) and current_hour = start_urzad
		{
			objective <- "w_urzedzie";
			the_target <- point(urzeduje);
		}

		reflex urzad_praca when: pracuje != nil and objective = "w_urzedzie" and current_hour = end_urzad
		{
			objective <- "pracuje";
			the_target <- point(pracuje);
		}

		reflex praca_lekarz  when: leczySie != nil and objective = "pracuje" and flip(pojdzie_do_lekarza) and current_hour = start_lekarz
		{
			objective <- "w_przychodni";
			the_target <- point(leczySie);
		}

		reflex lekarz_praca when: pracuje != nil and objective = "w_przychodni" and current_hour = end_lekarz
		{
			objective <- "pracuje";
			the_target <- point(pracuje);
		}

		reflex dom_rozrywka when: rozrywasie != nil and objective = "w_domu" and ((current_day < 5 and current_hour = start_rozrywka)
								  or (current_day > 4 and current_hour > 9))
		{
			objective <- "w_rozrywce";
			the_target <- point(rozrywasie);
		}

		reflex rozywka_dom when: mieszka != nil and objective = "w_rozrywce" and ((current_day < 5 and current_hour = end_rozrywka)
										  or (current_day > 4 and current_hour > 21))
		{
			objective <- "w_domu";
			the_target <- point(mieszka); 
		}
		
		reflex move when: the_target != nil
		{
			// przesun liste lokalizacji
			loop i from:1 to:length(loc) - 1{
				loc[i] <- loc[i-1];
			}
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
		
		//Reflex to update the number of infected
   		reflex compute_nb_infected {
   			number_I <- person count (each.is_infected);
   		}	
   		
   		//Reflex to make the agent infected if it is susceptible
	    reflex become_infected when: is_susceptible {
	    	float rate  <- 0.0;
	    	//computation of the infection according to the possibility of the disease to spread locally or not
    		int nb_hosts  <- 0;
    		int nb_hosts_infected  <- 0;
    		
    		// dodać sprawdzanie czy jest w budynku czy nie
    		
    		loop hst over: (person at_distance infection_radius) {
    			nb_hosts <- nb_hosts + 1;
    			if (hst.is_infected) {nb_hosts_infected <- nb_hosts_infected + 1;}
    		}
    		loop hst over: (slad at_distance infection_radius) {
    			nb_hosts <- nb_hosts + 1;
    			nb_hosts_infected <- nb_hosts_infected + 1;
    			// uwzględnić rozpraszanie się wirusa 0 im dalej - tym mniej (wykładniczo?)    			
    		}

    		if (nb_hosts > 0) {
    			rate <- nb_hosts_infected / nb_hosts;
    		}
    		
    		if (flip(beta * rate)) {
	        	is_susceptible <-  false;
	            is_infected <-  true;
	            is_immune <-  false;
	            color <-  #red;    
	            infection_begin <- time;
	        }
	        
	    }
	    
	    //Reflex to make the agent recovered if it is infected and if it success the probability
	    reflex become_immune when: (is_infected and time >= infection_begin + 2#week) {
	    	is_susceptible <- false;
	    	is_infected <- false;
	        is_immune <- true;
	        color <- #blue;
	    }
	    reflex spawn when: is_infected and ile_sladow < 12 {
	    	
	    	create slad {
	    		rodzic <- myself;
	    		numer <- myself.ile_sladow + 1;
	    		p1 <- myself.location;
	    		p2 <- myself.location;
	    	}
	    	
	    	ile_sladow <- ile_sladow + 1;
	    }
	}
	
}


experiment main_experiment  type: gui until: (time > 1 # d)
{
	parameter "Prawdopodobienstwo ze sie rozerwie" var: is_rozrywka category: "People" min: 0.0 max: 1.0;
	parameter "Prawdopodobienstwo ze pojdzie do urzedu" var: pojdzie_do_urzedu category: "People" min: 0.0 max: 1.0;
	parameter "Prawdopodobienstwo ze pojdzie do lekarza" var: pojdzie_do_lekarza category: "People" min: 0.0 max: 1.0;
	parameter "Rysuj ludzi jako obrazki" var: rysujLudziki category: "Ustawienia";
	parameter "Zapisz plik CSV" var: saveToCSV category: "Ustawienia";
	parameter "Nazwa pliku: " var: outputFile category: "Ustanienia";
	parameter "Miasto 3D" var: _3Dcity category: "Ustawienia";
	parameter "Prawdopodobienstwo zmiany parametru w lokalizacji" var: probChangeParamOnLoc category: "Model" min: 0.0 max: 1.0;
	
	parameter "Najwczesniejsza godzina do pracy" var: min_work_start category: "Times" min: 6 max: 8;
	parameter "Najpozniejsza godzina do pracy" var: max_work_start category: "Times" min: 8 max: 10;
	parameter "Najwczesniejsza godzina z pracy" var: min_work_end category: "Times" min: 12 max: 14;
	parameter "Najpozniejsza godzina z pracy" var: max_work_end category: "Times" min: 15 max: 19;
	parameter "Najwczesniejsza godzina rozpoczecia rozrywki" var: min_rozrywka_start category: "Times" min: 20 max: 21;
	parameter "Najpozniejsza godzina rozpoczecia rozrywki" var: max_rozrywka_start category: "Times" min: 21 max: 22;
	parameter "Najwczesniejsza godzina zakonczenia rozrywki" var: min_rozrywka_end category: "Times" min: 22 max: 23;
	parameter "Najpozniejsza godzina zakonczenia rozrywki" var: max_rozrywka_end category: "Times" min: 23 max: 24;
	parameter "Najwczesniejsza godzina rozpoczecia urzedu" var: min_urzad_start category: "Times" min: 10 max: 11;
	parameter "Najpozniejsza godzina rozpoczecia urzedu" var: max_urzad_start category: "Times" min: 11 max: 12;
	parameter "Najwczesniejsza godzina zakonczenia urzedu" var: min_urzad_end category: "Times" min: 13 max: 14;
	parameter "Najpozniejsza godzina zakonczenia urzedu" var: max_urzad_end category: "Times" min: 14 max: 15;
	parameter "Najwczesniejsza godzina pojscia do lekarza" var: min_lekarz_start category: "Times" min: 10 max: 11;
	parameter "Najpozniejsza godzina pojscia do lekarza" var: max_lekarz_start category: "Times" min: 11 max: 12;
	parameter "Najwczesniejsza godzina pojscia do lekarza" var: min_lekarz_end category: "Times" min: 13 max: 14;
	parameter "Najpozniejsza godzina pojscia do lekarza" var: max_lekarz_end category: "Times" min: 14 max: 15;
	parameter "SHP dla mieszkan:" var: shape_file_budynki category: "GIS";
	parameter "SHP dla drog:" var: shape_file_drogi category: "GIS";
	parameter "SHP dla granic:" var: shape_file_granice category: "GIS";
	parameter "SHP dla hexow:" var: shape_file_hexy category: "GIS";
	
		
	output
	{
		display miasto type: opengl ambient_light: 100
		{
			species heksy aspect: base;
			species budynki aspect: base;
			species drogi aspect: base;
			species person aspect: base;
			species slad aspect: base;
		}
		display chart refresh: every(10#cycles) {
				chart "Susceptible" type: series background: #lightgray style: exploded {
				data "susceptible" value: person count (each.is_susceptible) color: #green;
				data "infected" value: person count (each.is_infected) color: #red;
				data "immune" value: person count (each.is_immune) color: #blue;
				
				
			}
			
		
		}
		monitor "Sum susceptible" value: person count(each.is_susceptible);
		monitor "Sum infected" value: person count(each.is_infected);
		monitor "Sum immune" value: person count(each.is_immune);
		
		
	}
}