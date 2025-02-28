
/mob/living/carbon/human/restrained(ignore_grab)
	. = ((wear_suit && wear_suit.breakouttime) || ..())


/mob/living/carbon/human/canBeHandcuffed()
	if(get_num_arms(FALSE) >= 2)
		return TRUE
	else
		return FALSE

//gets assignment from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_assignment(if_no_id = "No id", if_no_job = "No job", hand_first = TRUE)
	var/obj/item/card/id/id = get_idcard(hand_first)
	if(id)
		. = id.assignment
	else
		var/obj/item/modular_computer/pda = wear_id
		if(istype(pda))
			. = pda.saved_job
		else
			return if_no_id
	if(!.)
		return if_no_job

//gets name from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_authentification_name(if_no_id = "Unknown")
	var/obj/item/card/id/id = get_idcard(FALSE)
	if(id)
		return id.registered_name
	var/obj/item/modular_computer/pda = wear_id
	if(istype(pda))
		return pda.saved_identification
	return if_no_id

//repurposed proc. Now it combines get_id_name() and get_face_name() to determine a mob's name variable. Made into a separate proc as it'll be useful elsewhere
/mob/living/carbon/human/get_visible_name()
	var/face_name = get_face_name("")
	var/id_name = get_id_name("")
	if(name_override)
		return name_override
	if(face_name)
		if(id_name && (id_name != face_name))
			return "[face_name] (as [id_name])"
		return face_name
	if(id_name)
		return id_name
	return "Unknown"

//Returns "Unknown" if facially disfigured and real_name if not. Useful for setting name when Fluacided or when updating a human's name variable
/mob/living/carbon/human/proc/get_face_name(if_no_face="Unknown")
	if( wear_mask && (wear_mask.flags_inv&HIDEFACE) )	//Wearing a mask which hides our face, use id-name if possible
		return if_no_face
	if( head && (head.flags_inv&HIDEFACE) )
		return if_no_face		//Likewise for hats
	var/obj/item/bodypart/O = get_bodypart(BODY_ZONE_HEAD)
	if( !O || (HAS_TRAIT(src, TRAIT_DISFIGURED)) || (O.brutestate+O.burnstate)>2 || cloneloss>50 || !real_name )	//disfigured. use id-name if possible
		return if_no_face
	return real_name

//gets name from ID or PDA itself, ID inside PDA doesn't matter
//Useful when player is being seen by other mobs
/mob/living/carbon/human/proc/get_id_name(if_no_id = "Unknown")
	var/obj/item/storage/wallet/wallet = wear_id
	var/obj/item/modular_computer/tablet/tablet = wear_id
	var/obj/item/card/id/id = wear_id
	if(istype(wallet))
		id = wallet.front_id
	if(istype(id))
		. = id.registered_name
	else if(istype(tablet))
		var/obj/item/computer_hardware/card_slot/card_slot = tablet.all_components[MC_CARD]
		if(card_slot?.stored_card)
			. = card_slot.stored_card.registered_name
	if(!.)
		. = if_no_id	//to prevent null-names making the mob unclickable
	return

//Gets ID card from a human. If hand_first is false the one in the id slot is prioritized, otherwise inventory slots go first.
/mob/living/carbon/human/get_idcard(hand_first = TRUE)
	//Check hands
	var/obj/item/card/id/id_card
	var/obj/item/held_item
	held_item = get_active_held_item()
	if(held_item) //Check active hand
		id_card = held_item.GetID()
	if(!id_card) //If there is no id, check the other hand
		held_item = get_inactive_held_item()
		if(held_item)
			id_card = held_item.GetID()

	if(id_card)
		if(hand_first)
			return id_card
		else
			. = id_card

	//Check inventory slots
	if(wear_id && !isnull(wear_id?.GetID()))//worn wallets return null if they don't have an ID
		id_card = wear_id.GetID()
		if(id_card)
			return id_card
	else if(belt)
		id_card = belt.GetID()
		if(id_card)
			return id_card

/mob/living/carbon/human/get_id_in_hand()
	var/obj/item/held_item = get_active_held_item()
	if(!held_item)
		return
	return held_item.GetID()

/**
 * Used to fetch all the cash a vendor can access from the human
 * See /mob/living/carbon/human/proc/get_cash_list() proc for the list of items and inventory slots it searches through
 */
/mob/living/carbon/human/proc/get_accessible_cash(list/cash_list = null)
	var/available_cash = 0
	if(!cash_list)
		cash_list = get_cash_list()
	if(!length(cash_list))
		return 0
	for(var/found_item in cash_list)
		if(istype(found_item, /obj/item/holochip))
			var/obj/item/holochip/chip_stack = found_item
			available_cash += chip_stack.credits
		if(istype(found_item, /obj/item/card/id))
			var/obj/item/card/id/id_card = found_item
			available_cash += id_card.registered_account.account_balance
	return available_cash

/**
 * Used by vendors to see if the human can spend a certain amount of cash.
 * Returns FALSE if they cannot, TRUE if they can and withdraws the cash.
 * Arguments:
 * * to_spend = how much cash needs to be deducted
 */
/mob/living/carbon/human/proc/spend_cash(to_spend)
	if(!to_spend)
		return FALSE
	var/list/cash_list = get_cash_list()
	if(!length(cash_list)) //We have no accessible cash items, early return
		return FALSE
	if(to_spend > get_accessible_cash(cash_list)) //If we don't have enough money, early return
		return FALSE
	for(var/obj/item/holochip/chip_stack in cash_list)//Loops are separate because we prioritize taking cash from holochips first, then ID cards
		if(chip_stack.credits >= to_spend)
			chip_stack.spend(to_spend, TRUE)
			return TRUE
		else
			var/temp_value_holder = to_spend
			to_spend -= chip_stack.credits
			chip_stack.spend(temp_value_holder, TRUE)
	for(var/obj/item/card/id/id_card in cash_list)
		var/temp_cash_holder = id_card.registered_account.account_balance
		if(temp_cash_holder >= to_spend)
			id_card.registered_account.adjust_money(-to_spend)
			return TRUE
		else
			id_card.registered_account.adjust_money(-to_spend)
			to_spend -= temp_cash_holder
	return FALSE

/**
 * Used to find which 'cash holding items' the human has that are accessible by a vendor.
 * Searches through both hands, ID and belt slots. Looks inside of wallets and PDAs.
 * Returns a list consisting of IDs and chip stacks.
 */
/mob/living/carbon/human/proc/get_cash_list(list/search_through = null)
	var/list/found_list = list()
	if(!search_through)
		search_through = list(get_active_held_item(), get_inactive_held_item(), wear_id, belt)
	for(var/obj/item/found_item in search_through)
		if(istype(found_item, /obj/item/modular_computer)) // if it's a PDA, we'll find a card
			var/obj/item/modular_computer/found_PDA = found_item
			var/obj/item/computer_hardware/card_slot/found_card_slot = found_PDA.all_components[MC_CARD]
			found_item = found_card_slot?.stored_card // swap found_item to the actual ID card we want to add
			if(!found_item) //Empty ID slot, skip it
				continue
				
		// we store detected cards and holochips into the returning list
		if(istype(found_item, /obj/item/card/id))
			var/obj/item/card/id/found_id = found_item
			if(found_id?.registered_account)
				found_list += found_id
		else if(istype(found_item, /obj/item/holochip))
			var/obj/item/holochip/found_chip = found_item
			if(found_chip.credits > 0)
				found_list += found_chip
		else if(istype(found_item, /obj/item/storage/wallet)) // if it's a wallet, find other cards and holochips recursively through this proc.
			var/obj/item/storage/wallet/found_wallet = found_item
			if(length(found_wallet.contents))
				found_list += get_cash_list(found_wallet.contents)
	if(length(found_list))
		return found_list
	else
		return null

/mob/living/carbon/human/IsAdvancedToolUser()
	if(HAS_TRAIT(src, TRAIT_MONKEYLIKE))
		return FALSE
	return TRUE//Humans can use guns and such

/mob/living/carbon/human/reagent_check(datum/reagent/R)
	return dna.species.handle_chemicals(R,src)
	// if it returns 0, it will run the usual on_mob_life for that reagent. otherwise, it will stop after running handle_chemicals for the species.


/mob/living/carbon/human/can_track(mob/living/user)
	if(wear_id && istype(wear_id.GetID(), /obj/item/card/id/syndicate))
		return FALSE
	if(istype(head, /obj/item/clothing/head))
		var/obj/item/clothing/head/hat = head
		if(hat.blockTracking)
			return FALSE

	return ..()

/mob/living/carbon/human/get_permeability_protection()
	var/list/prot = list("hands"=0, "chest"=0, "groin"=0, "legs"=0, "feet"=0, "arms"=0, "head"=0)
	for(var/obj/item/I in get_equipped_items())
		if(I.body_parts_covered & HANDS)
			prot["hands"] = max(1 - I.permeability_coefficient, prot["hands"])
		if(I.body_parts_covered & CHEST)
			prot["chest"] = max(1 - I.permeability_coefficient, prot["chest"])
		if(I.body_parts_covered & GROIN)
			prot["groin"] = max(1 - I.permeability_coefficient, prot["groin"])
		if(I.body_parts_covered & LEGS)
			prot["legs"] = max(1 - I.permeability_coefficient, prot["legs"])
		if(I.body_parts_covered & FEET)
			prot["feet"] = max(1 - I.permeability_coefficient, prot["feet"])
		if(I.body_parts_covered & ARMS)
			prot["arms"] = max(1 - I.permeability_coefficient, prot["arms"])
		if(I.body_parts_covered & HEAD)
			prot["head"] = max(1 - I.permeability_coefficient, prot["head"])
	var/protection = (prot["head"] + prot["arms"] + prot["feet"] + prot["legs"] + prot["groin"] + prot["chest"] + prot["hands"])/7
	return protection

/mob/living/carbon/human/can_use_guns(obj/item/G)
	. = ..()

	if(G.trigger_guard == TRIGGER_GUARD_NORMAL)
		if(src.dna.check_mutation(HULK))
			to_chat(src, "<span class='warning'>Your meaty finger is much too large for the trigger guard!</span>")
			return FALSE
		if(HAS_TRAIT(src, TRAIT_NOGUNS))
			to_chat(src, "<span class='warning'>Your fingers don't fit in the trigger guard!</span>")
			return FALSE
	if(mind)
		if(mind.martial_art && mind.martial_art.no_guns) //great dishonor to famiry
			to_chat(src, "<span class='warning'>Use of ranged weaponry would bring dishonor to the clan.</span>")
			return FALSE

	return .

/mob/living/carbon/human/proc/get_bank_account()
	RETURN_TYPE(/datum/bank_account)
	var/datum/bank_account/account
	var/obj/item/card/id/I = get_idcard()

	if(I?.registered_account)
		account = I.registered_account
		return account

	return FALSE

/mob/living/carbon/human/can_see_reagents()
	. = ..()
	if(.) //No need to run through all of this if it's already true.
		return
	if(isclothing(glasses) && (glasses.clothing_flags & SCAN_REAGENTS))
		return TRUE
	if(isclothing(head) && (head.clothing_flags & SCAN_REAGENTS))
		return TRUE
	if(isclothing(wear_mask) && (wear_mask.clothing_flags & SCAN_REAGENTS))
		return TRUE

/mob/living/carbon/human/can_see_boozepower()
	. = ..()
	if(.)
		return
	if(isclothing(glasses) && (glasses.clothing_flags & SCAN_BOOZEPOWER))
		return TRUE
	if(isclothing(head) && (head.clothing_flags & SCAN_BOOZEPOWER))
		return TRUE
	if(isclothing(wear_mask) && (wear_mask.clothing_flags & SCAN_BOOZEPOWER))
		return TRUE
