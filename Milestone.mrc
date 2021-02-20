; Milestone AI - Proof of Concept v1.1
;
; TODO:
; -----
; 1. Feature: Account for playing specials during the 10m games at the 2m warning! (Or time it from that point?)
;
;      if (*2 minute warning!* iswm $1-) { }
;
; 2. Change: Fix the hindering of players so that a random victim is chosen if all distances are zero. (E.g. New Game)
; 3. To combat people leaving then joining for "new cards," do CO when the game starts.


#Milestone on
alias -l Milestone.attack.timer { return 2000 }
; 2000ms = 2s.
alias -l Milestone.bot { return MB }
alias -l Milestone.chan { return #Milestone }
alias -l Milestone.cards { return 87 }
alias -l Milestone.cards.atk { return acc accident,ft flat flattire,oog out nogas outofgas,sl speed limit speedlimit }
alias -l Milestone.cards.rep { return rep repairs,st spare sparetire,gas gasoline,eol endoflimit end }
alias -l Milestone.join.timer { return 50 }
; 50ms = 0.05s.
alias -l Milestone.network { return GlobalGamers }
alias -l Milestone.rep.timer { return 500 }
; 500ms = 1/2s.
alias -l Milestone.timer { return 1250 }
; 1250ms = 1.25s.
alias -l Milestone.whoops.reply { return Whoops! }

on *:disconnect:{
  if ($network == $Milestone.network) { milestone_stop }
}
on me:*:join:#Milestone:{
  if ($network == $Milestone.network) { milestone_login }
}
on me:*:kick:#Milestone:{
  if ($network == $Milestone.network) { milestone_stop }
}
on *:nick:{
  if ($network == $Milestone.network) {
    if ($newnick ison $Milestone.chan) {
      if (($hget(MilestoneUsers,$nick)) || ($newnick == $me)) {
        var %t.1 = Milestone $+ $iif($newnick != $me,Users), %t.2 = $iif(%t.1 == MilestoneUsers,$nick,Self), %t.3 = $iif($newnick != $me,$v1,Self), %t.4 = $hget(%t.1,%t.2)
        hdel %t.1 %t.2
        hadd -m %t.1 %t.3 $gettok(%t.4,1-5,44) $+ , $+ $newnick
        if ($newnick == $me) { hadd -m Milestone PrevNick $nick }
      }
    }
  }
}
on *:notice:*:?:{
  if ($network == $Milestone.network) {
    if ($nick == $Milestone.bot) {
      tokenize 32 $strip($1-)
      if (Cards:* iswm $1-) { hadd -m Milestone Cards $left($right($remove($replace($2-, $chr(93), ¦), $+($chr(32),$chr(91))), -1), -1) }

      ; ,-> Error correcting. Might be deprecated if I can add something that tracks the repair/attack cards people play, but will be retained as "backup."
      if (*play another card* iswm $1-) {
        if (*already* iswm $1-) { var %nick = $1, %tmp.a = Play, %tmp.b = -, %tmp.c = 1 }
        if (*currently* iswm $1-) { var %nick = $left($1,-2), %tmp.a = currently, %tmp.b = +, %tmp.c = 1 }
        if (*so you must* iswm $1-) { var %nick = $1, %tmp.a = so, %tmp.b = -, %tmp.c = 2 }

        var %state = $gettok($1-,$calc($findtok($1-,%tmp.a,1,32) %tmp.b 1),32)
        if ($istok($+(Ace,$chr(44)) ACCIDENT.,%state,32)) { milestone_update_user %nick %tmp.c 2 }
        if ($istok(FLAT FLATTIRE. $+(Proof,$chr(44)) TIRE.,%state,32)) { milestone_update_user %nick %tmp.c 3 }
        if ($istok(GAS. OUT OUTOFGAS. $+(Tank,$chr(44)),%state,32)) { milestone_update_user %nick %tmp.c 4 }
        if ($istok(LIMIT. SPEED SPEEDLIMIT. $+(Way,$chr(44)),%state,32)) { milestone_update_user %nick %tmp.c 5 }
        ; Try again...
        ; msg $Milestone.chan $Milestone.whoops.reply
        .timermilestone_self_repair -m 1 $Milestone.timer milestone_self_repair
      }
    }
  }
}
on me:*:part:#Milestone:{ milestone_stop }
on *:signal:milestone_play_card:{
  var %nick = $left($1,-1)

  ; ,-> This code is fucking ugly, and will need updating at some point...
  var %state = $gettok($1-,$calc($findtok($1-,State:,1,32) + 1),32)
  if ($gettok($1-,$calc($findtok($1-,Travelled:,1,32) - 1),32) == Limit) {
    var %extra = 1
    ; milestone_update_user %nick 1 5
  }
  else {
    var %tmp.1 = Milestone $+ $iif(%nick != $me,Users), %tmp.2 = $iif(%nick != $me,$v1,Self), %tmp.3 = $hget(%tmp.1,%tmp.2)
    var %extra = $iif($gettok(%tmp.3,5,44) == 2,2,0)
    ; milestone_update_user %nick $iif($gettok(%tmp.3,5,44) == 2,2,0) 5
  }
  var %distance = $gettok($1-,$calc($findtok($1-,Travelled:,1,32) + 1),32)
  hadd -m Milestone $+ $iif(%nick != $me,Users) $iif(%nick != $me,$v1,Self) $milestone_user_state(%distance,%state,%extra,%nick)
  ; milestone_update_user %nick %distance 1
  ; milestone_update_user %nick <state> <token>

  if ((%nick == $me) || (%nick == $hget(Milestone,PrevNick))) {
    ; if (%nick == $me) {
    if (($hget(Milestone,CardCount) >= 0) && ($hget(Milestone,CardCount) <= $hget(Milestone,PlayerThresh))) {
      if ($milestone_count_specials > 0) {
        ; `-> We're about to run out of cards, so play all the specials I have.
        var %specials = Driving Ace,Puncture Proof,Extra Tank,Right of Way
        tokenize 44 %specials
        milestone_play_specials $*
      }
      else { goto milestone_self_repair }
    }
    else {
      :milestone_self_repair
      .timermilestone_self_repair -m 1 $Milestone.rep.timer milestone_self_repair
    }
  }
}
on *:text:*:#Milestone:{
  if ($network == $Milestone.network) {
    if ($nick == $Milestone.bot) {
      tokenize 32 $strip($1-)
      if (*it is your turn to play* iswm $1-) {
        if ($hget(Milestone,CardCount)) { hdec Milestone CardCount 1 }
        /*
        if (!$hget(Milestone,CurrPlayer)) { hadd -m Milestone CurrPlayer $left($1,-1) | goto milestone_player_check }
        else {
          :milestone_player_check
          if ($left($1,-1) != $hget(Milestone,CurrPlayer)) {
            ; The card the user played was successful, we have now moved onto the next player.
            if ($hget(Milestone,PushUpdate)) {
              milestone_update_user $hget(Milestone,PushUpdate)
              hdel Milestone PushUpdate
            }
            hadd -m Milestone CurrPlayer $left($1,-1)
          }
        }
        */
        .timermilestone_play_card -m 1 $Milestone.timer .signal -n milestone_play_card $1-
      }

      if (*miles for a total of* iswm $1-) { milestone_update_user $1 $gettok($1-,9,32) 1 }
      if (*you are a Driving Ace* iswm $1-) { milestone_update_user $left($1,-1) 2 2 }
      if (*you now have Puncture Proof tires* iswm $1-) { milestone_update_user $left($1,-1) 2 3 }
      if (*eternally with the Extra Tank card* iswm $1-) { milestone_update_user $left($1,-1) 2 4 }
      if (*you now have the Right of Way* iswm $1-) { milestone_update_user $left($1,-1) 2 5 }

      if (*has joined the game* iswm $1-) {
        hadd -m Milestone $+ $iif($1 != $me,Users) $iif($1 != $me,$v1,Self) 0,0,0,0,0, $+ $1
        if ($hget(Milestone,CardCount)) { hdec Milestone CardCount 6 }
        ; `-> Decrease by six for the cards the player got...
      }

      if (*Doubling the deck* iswm $1-) { msg $Milestone.chan CO }
      if (Players this game:* iswm $1-) { hadd -m Milestone PlayerThresh $milestone_count_players($calc($numtok($gettok($1-,4-,32),32) - 1)) }
      if ((Deck Count:* iswm $1-) && ($hget(Milestone,CardCount))) {
        if ($3 != $hget(Milestone,CardCount)) { hadd -m Milestone CardCount $3 }
      }

      if ($1- == GAME OVER!) { milestone_stop }
      if ($1- == Starting a new game of Milestone!) { milestone_stop | .timermilestone_join -m 1 $Milestone.join.timer msg $Milestone.chan Join }
      if (Perpetual dealing: Disabled* iswm $1-) { hadd -m Milestone CardCount $Milestone.cards }
      /*
      if (*Time Limit: 10 Minutes* iswm $1-) { hadd -m Milestone Timed 1 }
      if (Milestone game starting!* iswm $1-) {
        if ($hget(Milestone,Timed)) { }
      }
      */
      if ((*.*Removed* iswm $1-) || (*.*Removing* iswm $1-)) {
        if ($hget(MilestoneUsers,$1)) {
          if ($hget(Milestone,PlayerThresh) > 4) { hdec Milestone PlayerThresh 1 | msg $Milestone.chan CO }
          hdel MilestoneUsers $1
        }
      }
      if (*it is your turn*warning* iswm $1-) {
        if ($left($1,-1) == $me) { milestone_discard_cards }
      }
    }
    /*
    if ($nick == $hget(Milestone,CurrPlayer)) {
      if ($findtok($Milestone.cards.atk,$matchtok($Milestone.cards.atk,$1,1,44),44)) { hadd -m Milestone PushUpdate $2 1 $calc($v1 + 1) }
      if ($findtok($Milestone.cards.rep,$matchtok($Milestone.cards.rep,$1,1,44),44)) { hadd -m Milestone PushUpdate $nick 0 $calc($v1 + 1) }
    }
    */
  }
}
on *:unload:{ milestone_stop }

alias -l milestone_count_players {
  ; 0 - 3 would account for all four specials; however, we account for four due to the fact I could be the player playing when there's four cards remaining instead of three.
  ; If I didn't do this, I would be unable to play all four cards if I had them due to the fact there would only be three cards remaining. (So only three would be played.)
  ; The numbers increase with more players for this same reason.
  ; ,-> return $calc($1 + 3)
  var %x = 1 4,2 5,3 6,4 7,5 8,6 9,7 10,8 11
  return $gettok($wildtok(%x,$1 *,1,44),2,32)
}
alias -l milestone_count_specials { return $calc($left($regsubex($str(.,$numtok($hget(Milestone,Cards),166)),/./g,$+($milestone_is_special($gettok($hget(Milestone,Cards),\n,166)),+)),-1)) }
alias -l milestone_discard_cards {
  var %cards = $hget(Milestone,Cards), %d = $gettok($hget(Milestone,Self),1,44)
  if ($hget(Milestone,AmStuck)) { hdel Milestone AmStuck }
  if ($hget(Milestone,LimitWin)) { hdel Milestone LimitWin }

  if (($istok(%cards,Driving Ace,166)) || ($gettok($hget(Milestone,Self),2,44) == 2)) {
    if ($istok(%cards,Repairs,166)) { msg $Milestone.chan Discard Repairs | halt }
  }
  if (($istok(%cards,Puncture Proof,166)) || ($gettok($hget(Milestone,Self),3,44) == 2)) {
    if ($istok(%cards,Spare Tire,166)) { msg $Milestone.chan Discard Spare | halt }
  }
  if (($istok(%cards,Extra Tank,166)) || ($gettok($hget(Milestone,Self),4,44) == 2)) {
    if ($istok(%cards,Gasoline,166)) { msg $Milestone.chan Discard Gasoline | halt }
  }
  if (($istok(%cards,Right of Way,166)) || ($gettok($hget(Milestone,Self),5,44) == 2)) {
    if ($istok(%cards,End of Limit,166)) { msg $Milestone.chan Discard EoL | halt }
  }
  if (($istok(%cards,200,166)) && (%d > 800)) { msg $Milestone.chan Discard 200 | halt }
  if (($istok(%cards,100,166)) && (%d > 900)) { msg $Milestone.chan Discard 100 | halt }
  if (($istok(%cards,75,166)) && (%d > 925)) { msg $Milestone.chan Discard 75 | halt }
  if (($istok(%cards,50,166)) && (%d > 950)) { msg $Milestone.chan Discard 50 | halt }

  ; }-> Otherwise...

  ; ,-> Discard in order of "least importance."
  var %cards = 25,50,75,Speed Limit,Accident,Flat Tire,Out of Gas,Repairs,Spare Tire,Gasoline,End of Limit,100,200
  ; `-> Specials obviously aren't included because that would be stupid. :P
  tokenize 44 %cards
  milestone_discard_card $*
}
alias -l milestone_discard_card {
  var %cards = End of Limit,EoL,Speed Limit,Limit,Flat Tire,Flat,Out of Gas,OoG,Spare Tire,Spare
  if ($istok($hget(Milestone,Cards),$1-,166)) { msg $Milestone.chan Discard $replace($1-, [ %cards ] ) | halt }
}
alias -l milestone_distance_calc {
  var %d = $iif($1 != 0,$v1,0), %x = 200,100,75,50,25
  tokenize 44 %x
  scon -r if ( $!calc( %d + $* ) <= 1000 ) { return $* }
}
alias -l milestone_hinder_players {
  ; /milestone_hinder_players <data>
  var %n = $gettok($1-,6,44)
  ; if ($gettok($1-,1,44) > 0) {
  if (($gettok($1-,2,44) == 0) && ($gettok($1-,3,44) != 1) && ($gettok($1-,4,44) != 1) && ($istok($hget(Milestone,Cards),Accident,166))) { msg $Milestone.chan Accident %n | .timermilestone_self_travel off | halt }
  if (($gettok($1-,2,44) != 1) && ($gettok($1-,3,44) == 0) && ($gettok($1-,4,44) != 1) && ($istok($hget(Milestone,Cards),Flat Tire,166))) { msg $Milestone.chan Flat %n | .timermilestone_self_travel off | halt }
  if (($gettok($1-,2,44) != 1) && ($gettok($1-,3,44) != 1) && ($gettok($1-,4,44) == 0) && ($istok($hget(Milestone,Cards),Out of Gas,166))) { msg $Milestone.chan OoG %n | .timermilestone_self_travel off | halt }
  if ($gettok($1-,5,44) == 0) {
    ; ,-> This is the only one that can be called in conjuncture with the others...
    if ($istok($hget(Milestone,Cards),Speed Limit,166)) { msg $Milestone.chan Limit %n | .timermilestone_self_travel off | halt }
  }
  ; }
  .timermilestone_self_travel -m 1 $Milestone.attack.timer milestone_self_travel
}
alias -l milestone_hinder_players_pre {
  ; ,-> Winning takes priority...
  if ($hget(Milestone,AmStuck)) { goto milestone_skip_win_check }
  var %cards = $hget(Milestone,Cards), %d = $gettok($hget(Milestone,Self),1,44)
  if ((%d == 800) && ($istok(%cards,200,166))) { milestone_self_travel }
  if ((%d == 900) && ($istok(%cards,100,166))) { milestone_self_travel }
  if ((%d == 925) && ($istok(%cards,75,166))) { milestone_self_travel }
  if ((%d == 950) && ($istok(%cards,50,166))) { milestone_self_travel }
  if ((%d == 975) && ($istok(%cards,25,166))) { milestone_self_travel }
  else {
    :milestone_skip_win_check
    ; ,-> I can't win, so sort the users by highest distance then attack them...
    tokenize 166 $sorttok($regsubex($str(.,$hget(MilestoneUsers,0).data),/./g,$+($hget(MilestoneUsers,\n).data,¦)),166,nr)
    milestone_hinder_players $*
  }
}
alias -l milestone_is_special { return $iif($istok(Driving Ace¦Puncture Proof¦Extra Tank¦Right of Way,$1,166),1,0) }
alias -l milestone_play_specials {
  var %specials = Driving Ace,Ace,Puncture Proof,PP,Extra Tank,Tank,Right of Way,RoW
  if ($istok($hget(Milestone,Cards),$1-,166)) {
    msg $Milestone.chan $replace($1-, [ %specials ] )
    if (($1- == Right of Way) && ($hget(Milestone,LimitWin))) { msg $Milestone.chan 25 }
    halt
  }
}
alias -l milestone_self_repair {
  if ($hget(Milestone,AmStuck)) { hdel Milestone AmStuck }
  if ($hget(Milestone,LimitWin)) { hdel Milestone LimitWin }
  var %data = $hget(Milestone,Self)
  if ($gettok(%data,2,44) == 1) {
    if ($istok($hget(Milestone,Cards),Driving Ace,166)) { msg $Milestone.chan Ace | halt }
    if ($istok($hget(Milestone,Cards),Repairs,166)) { msg $Milestone.chan Repairs | halt }
    hadd -m Milestone AmStuck 1
  }
  if ($gettok(%data,3,44) == 1) {
    if ($istok($hget(Milestone,Cards),Puncture Proof,166)) { msg $Milestone.chan PP | halt }
    if ($istok($hget(Milestone,Cards),Spare Tire,166)) { msg $Milestone.chan Spare | halt }
    hadd -m Milestone AmStuck 1
  }
  if ($gettok(%data,4,44) == 1) {
    if ($istok($hget(Milestone,Cards),Extra Tank,166)) { msg $Milestone.chan Tank | halt }
    if ($istok($hget(Milestone,Cards),Gasoline,166)) { msg $Milestone.chan Gasoline | halt }
    hadd -m Milestone AmStuck 1
  }
  if ($gettok(%data,5,44) == 1) {
    if ($istok($hget(Milestone,Cards),Right of Way,166)) { msg $Milestone.chan RoW | halt }
    if (($calc($gettok(%data,1,44) + 25) == 1000) && ($istok($hget(Milestone,Cards),25,166))) {
      hadd -m Milestone LimitWin 1
      goto milestone_limit_win
    }
    if ($istok($hget(Milestone,Cards),End of Limit,166)) { msg $Milestone.chan EoL | halt }
    if (!$hget(Milestone,AmStuck)) {
      ; Incase I'm something else like OoG...
      if ($istok($hget(Milestone,Cards),25,166)) {
        :milestone_limit_win
        if ($hget(Milestone,LimitWin)) {
          var %specials = Driving Ace,Puncture Proof,Extra Tank,Right of Way
          tokenize 44 %specials
          milestone_play_specials $*
        }
        msg $Milestone.chan 25
        halt
      }
    }
    hadd -m Milestone AmStuck 1
  }
  .timermilestone_hinder_players_pre -m 1 $Milestone.timer milestone_hinder_players_pre
}
alias -l milestone_self_travel {
  if ($hget(Milestone,AmStuck)) { goto skip_milestone_travel }
  var %d = $gettok($hget(Milestone,Self),1,44)
  goto $milestone_distance_calc(%d)
  :200
  if ($istok($hget(Milestone,Cards),200,166)) { var %c = 200 | goto play_milestone_card }
  :100
  if ($istok($hget(Milestone,Cards),100,166)) { var %c = 100 | goto play_milestone_card }
  :75
  if ($istok($hget(Milestone,Cards),75,166)) { var %c = 75 | goto play_milestone_card }
  :50
  if ($istok($hget(Milestone,Cards),50,166)) { var %c = 50 | goto play_milestone_card }
  :25
  if ($istok($hget(Milestone,Cards),25,166)) { var %c = 25 | goto play_milestone_card }
  goto skip_milestone_travel
  :play_milestone_card
  if ($calc(%d + %c) == 1000) {
    ; Play all the specials because I've won!
    var %specials = Driving Ace,Puncture Proof,Extra Tank,Right of Way
    tokenize 44 %specials
    milestone_play_specials $*
  }
  msg $Milestone.chan %c
  halt
  :skip_milestone_travel
  milestone_discard_cards
}
alias milestone_stop { .timermilestone* off | hfree -w Mile* }
alias -l milestone_update_user {
  ; /milestone_update_user <nick> <new value> <token>
  var %t.1 = Milestone $+ $iif($1 != $me,Users), %t.2 = $iif($1 != $me,$v1,Self), %t.3 = $hget(%t.1,%t.2)
  hadd -m %t.1 %t.2 $puttok(%t.3,$2,$3,44)
}
; This function will need to be deprecated at some point...
alias -l milestone_user_state {
  var %t.1 = Milestone $+ $iif($4 != $me,Users), %t.2 = $iif($4 != $me,$v1,Self), %t.3 = $hget(%t.1,%t.2)
  var %body.state = $iif($2 == ACCIDENT,1,$iif($gettok(%t.3,2,44) == 2,2,0))
  var %tire.state = $iif($2 == FLAT,1,$iif($gettok(%t.3,3,44) == 2,2,0))
  var %gas.state = $iif($2 == OUT,1,$iif($gettok(%t.3,4,44) == 2,2,0))
  return $1 $+ , $+ %body.state $+ , $+ %tire.state $+ , $+ %gas.state $+ , $+ $3 $+ , $+ $4
}
#Milestone end

; EOF
