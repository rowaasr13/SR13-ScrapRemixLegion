# SR13-ScrapRemixLegion
by rowaasr13

* https://www.curseforge.com/wow/addons/sr13-scrapremixlegion

### !!!REQUIRES [OOCDo ("Out-of-combat Do" macro button")](https://www.curseforge.com/wow/addons/oocdo) TO ACTUALLY PERFORM CAST AND CLICK!!! Without it it will only push items into scrap machine.

A one-click (macro) button that does all of:
* Casts Unraveling Sands (when scrapping machine interface is not open already)
* Pushes items into scrapping maching
* Clicks actual "Scrap" button

The only thing you need to do yourself is to right click on those Unraveling Sands when they appear - there are no way to do that automatically.

## How it is different?
I've checked out other scrapping addons for Legion Remix and couldn't find a feature I wanted - ability to scrap duplicates.
At maximum 740 ilevel I want to keep one copy of each item with different stats and scrap all duplicates. Brief search revealed that other people had same idea, so I decided to write my own scrapper just for that.

## What is scrapped?
* Duplicates, as mentioned above: i.e. any item that has same ilevel, same slot and same set of 2/3 bonus stats on it. It does not matter if items could have different names/appearances.
* All armor that are lower ilevel than your best one: i.e. if you have 740 boots equipped or somewhere in inventory, any other boots lower than 740 is scrapped, but those that are of same level are left alone.
* All accessories that are lower ilevel than your best one: same as with armor, except it compares items directly not abilities. I.e. if you have 740 "Volatile Chaos Talisman" trinket with "Touch of Malice", only other copies of "Volatile Chaos Talisman" of lower level will be scrapped. It does NOT compare ilevels with "Pendant of the Watchful Eye" which carries same ability but for different slot.

## How to use?
One time setup: copy/paste following into chat:
```lua
/run _G["SR13-ScrapRemixLegion"].CreateMacro()
```
This will create macro in your general macros with name "ScrapRemixLegion" and Unraveling Sands icon which you can drag onto your action bars. Click it to do everything listed above.

## Any configuration?
There's no confgiration UI, since it's supposed to be fire and forget type macro, but you can set-up it once by adding special parameters. Add them into first line between `({})` brackets.
Examples below show full adjusted line that you can just copy/paste inside macro, replacing existing line. Make sure to keep other lines intact.
If you feel you've broke macro, you can just delete macro completely and go back to one time setup above.

Disable clicking on scrap button if you want to inspect items before that:
```lua
/run _G["SR13-ScrapRemixLegion"].ScrapRemixLegion({ scrap = false })
```

By default bags are scanned forward: items that are above are left alone and items that are below gets scrapped. If you keep your items to be left at bottom of bags, you can enable scan in reverse:
```lua
/run _G["SR13-ScrapRemixLegion"].ScrapRemixLegion({ reverse = true })
```

All options can be combined with comma. Example:
```lua
/run _G["SR13-ScrapRemixLegion"].ScrapRemixLegion({ scrap = false, reverse = true })
```

## What other lines do in this macro?
They're **supposed** to make it work as replacement of zone ability button.
So zone ability itself disappears when macro is on your action bars and your action bars show ability cooldown/tooltip properly.
Unfortunately there are currently bug with macros unable to find correct copy of "Unraveling Sands" among several existing in game, so more often it does not work.
I've filled a bug in UI tracker for it, but considering that half of Remix is passed already, I don't expect it to be fixed in time.
