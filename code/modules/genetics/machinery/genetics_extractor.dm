/*
	=================Genetics Pulper=================
	One of the most simple standalone machines in the department, but fairly important in its own right.
	Meat goes in, Sample plates come out. The sample plates hold the mutations and cloning info of the meat the object came from.
	It also talks in a really peppy voice, even while grinding creatures into a fine paste.

	25.04.24 - CFW -It no longer talks, courtesy of Dr. Farson, as requested by several players
*/
/obj/machinery/genetics/pulper
	name = "Xenofauna Genetics Pulper"
	desc = "A morosely clinical device that takes raw meat (or whole bodies), destroys it on a cellular level, and organizes as much genetic information as it can into sample plates."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "processor"
	var/gib_time = 40 // Time from starting until sample plates appear.
	density = TRUE
	anchored = TRUE
	layer = BELOW_OBJ_LAYER
	circuit = /obj/item/circuitboard/genetics/pulper
	var/list/meat = list() //Container for meat added to the extractor.
	var/mob/living/occupant = null //Container for whole mobs loaded into the extractor
	var/occupant_meat_count = 0 //The amount of meat an occupant would have.
	var/occupant_meat_type
	var/occupant_bonus = 2 //The amount of EXTRA Sample plates adding a whole mob to a pulper gives.
	var/meat_limit = 5	//The maximum amount of individual pieces of meat that can be loaded into the device
	var/pulping = FALSE //Whether or not the device is extracting genetics

/obj/machinery/genetics/pulper/attackby(obj/item/I, mob/user)
	if(!user.stats?.getPerk(PERK_SI_SCI) && !usr.stat_check(STAT_COG, 35) && !user.stats?.getPerk(PERK_NERD) && !usr.stat_check(STAT_BIO, 70)) //So someone that has basic chems or level up can be an assent
		to_chat(usr, SPAN_WARNING("This machine is too advanced for you to use."))
		return

	if(default_deconstruction(I, user))
		return
	if(default_part_replacement(I, user))
		return
	if(stat & (NOPOWER|BROKEN))
		to_chat(user, SPAN_WARNING("The pulper is inactive and ominously silent."))
		return
	if(pulping)
		src.visible_message(SPAN_DANGER("The pupler is currently running, you have to wait for it to finish."))
		return

	//Inserting a sample
	if(istype(I, /obj/item/reagent_containers/snacks/meat))
		if(meat.len >= 5)
			src.visible_message(SPAN_WARNING("The pulper is full, please turn it on and process the contents before filling it again."))
			return
		if(occupant)
			src.visible_message(SPAN_WARNING("The pulper is full, please turn it on and process the contents before filling it again."))
			return

		user.drop_item()
		I.forceMove(src)
		src.meat += I

		to_chat(user, SPAN_WARNING("You shove meat into the pulper."))
		return
	else
		. = ..()

/obj/machinery/genetics/pulper/affect_grab(mob/user, mob/living/target, state)
	if(stat & (NOPOWER|BROKEN))
		to_chat(user, SPAN_WARNING("The pulper is inactive and ominously silent."))
		return
	if(pulping)
		src.visible_message(SPAN_WARNING("The pupler is currently running, you have to wait for it to finish."))
		return
	if(istype(target, /mob/living/carbon/human))
		src.visible_message(SPAN_WARNING("The pulper's biosaftey sensors activate and prevent you from putting a human inside it."))
		return
	if(meat.len > 0)
		src.visible_message(SPAN_WARNING("The pulper is full, please turn it on and process the contents before filling it again."))
		return

	//Check if the creature actually bears meat, IE: It has DNA
	var/temp_meat_count = 0
	var/temp_meat_type
	if (isanimal(target))
		var/mob/living/simple/animal = target
		if(ispath(animal.meat_type, /obj/item/reagent_containers/snacks/meat))
			temp_meat_count = animal.meat_amount
			temp_meat_type = animal.meat_type
	else if (issuperioranimal(target))
		var/mob/living/carbon/superior/s_animal = target
		if(ispath(s_animal.meat_type, /obj/item/reagent_containers/snacks/meat))
			temp_meat_count = s_animal.meat_amount
			temp_meat_type = s_animal.meat_type
	else if(istype(target, /mob/living/carbon/slime))
		temp_meat_count = 1 //slimes don't normally have meat. So we add one so we can pull a single sample off.
		temp_meat_type = /obj/item/reagent_containers/snacks/meat

	if(temp_meat_count <= 0)
		src.visible_message(SPAN_WARNING("This creature doesn't have any genetic material to extract."))

	//Do the insertion step
	if(do_after(user, 60, target))
		src.visible_message(SPAN_DANGER("[user] has forced [target] into \the [src]!"))
		occupant = target
		occupant_meat_count = temp_meat_count
		occupant_meat_type = temp_meat_type
		target.loc = src

/obj/machinery/genetics/pulper/attack_hand(mob/user as mob)
	if(stat & (NOPOWER|BROKEN))
		to_chat(user, SPAN_WARNING("The pulper is inactive and ominously silent."))
		return
	if(!user.stats?.getPerk(PERK_SI_SCI) && !usr.stat_check(STAT_COG, 35) && !user.stats?.getPerk(PERK_NERD) && !usr.stat_check(STAT_BIO, 70)) //So someone that has basic chems or level up can be an assent
		to_chat(usr, SPAN_WARNING("This machine is too advanced for you to use."))
		return
	if(pulping)
		src.visible_message( SPAN_DANGER("The pupler is currently running, you have to wait for it to finish."))
		return
	else
		src.startpulping(user)

/obj/machinery/genetics/pulper/proc/startpulping(mob/user as mob)
	if(pulping)
		return

	if(!occupant && meat.len == 0)
		playsound(loc, 'sound/machines/blender.ogg', 50, 1)
		visible_message(SPAN_DANGER("You hear a loud metallic grinding sound."))
		return

	use_power(1000)

	pulping = TRUE

	playsound(loc, 'sound/machines/juicer.ogg', 50, 1)
	visible_message(SPAN_DANGER("You hear a loud squelchy grinding sound."))

	update_icon()
	spawn(gib_time) //Escape in time?
		if(occupant && (occupant.loc == src)  && occupant_meat_count && ispath(occupant_meat_type, /obj/item/reagent_containers/snacks/meat))
			src.visible_message(SPAN_WARNING("The pulper pings as it extracts the genetic material from [occupant]."))
			//big-range splatter
			playsound(src.loc, 'sound/effects/splat.ogg', 50, 1)
			var/obj/effect/decal/cleanable/blood/splatter/animated/B = new(src.loc)
			B.target_turf = pick(range(3, src))

			var/datum/genetics/genetics_holder/mob_genes = new /datum/genetics/genetics_holder()
			mob_genes.initializeFromMob(occupant)

			var/sample_plates_to_make = occupant_meat_count + occupant_bonus
			for(var/i=1 to sample_plates_to_make)
				var/obj/item/genetics/sample/new_sample = new /obj/item/genetics/sample(mob_genes)
				new_sample.name = "[new_sample.name] ([occupant.name])"
				new_sample.forceMove(loc)

			src.occupant.attack_log += "\[[time_stamp()]\] Was gibbed by <b>[user]/[user.ckey]</b>" //One shall not simply gib a mob unnoticed!
			user.attack_log += "\[[time_stamp()]\] Gibbed <b>[src.occupant]/[src.occupant.ckey]</b>"
			msg_admin_attack("[user.name] ([user.ckey]) gibbed [src.occupant] ([src.occupant.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

			//kill the occupant
			occupant.damage_through_armor(201, BRUTE, BP_CHEST)
			var/mob/living/to_delete = occupant
			occupant = null
			qdel(to_delete)
			occupant_meat_count = 0

		if(meat.len >= 0)
			src.visible_message(SPAN_WARNING("The pulper pings as it extracts the genetic material from the meat."))

			//low-range splatter
			playsound(src.loc, 'sound/effects/splat.ogg', 50, 1)
			var/obj/effect/decal/cleanable/blood/splatter/animated/B = new(src.loc)
			B.target_turf = pick(range(2, src))

			for(var/obj/item/reagent_containers/snacks/meat/meat_target in meat)
				//Ensures we only do this if the meat has genetics holders
				if(meat_target.source_name)
					var/datum/genetics/genetics_holder/meat_genes =  new /datum/genetics/genetics_holder()
					meat_genes.initializeFromMeat(meat_target)
					var/obj/item/genetics/sample/new_sample = new /obj/item/genetics/sample(meat_genes)
					new_sample.name = "[new_sample.name] ([meat_target.name])"
					new_sample.forceMove(loc)

			meat = list()

		pulping = FALSE
		update_icon()

/obj/machinery/genetics/pulper/return_air_for_internal_lifeform()
	//Gibber isn't airtight, things inside it can breathe
	if(loc)
		return loc.return_air()
	else
		return null

/obj/machinery/genetics/pulper/update_icon()
	if(pulping)
		icon_state = "processor1"
	else
		icon_state = "processor"


/obj/machinery/genetics/pulper/verb/eject()
	set category = "Object"
	set name = "Empty Pulper"
	set src in oview(1)

	if(occupant)
		src.occupant.loc = src.loc
		src.occupant = null

	occupant_meat_count = 0

	for(var/obj/O in meat)
		O.loc = src.loc
	meat = list()

	return
