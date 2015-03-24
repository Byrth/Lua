# Organizer

A multi-purpose inventory management solution. Similar to GearCollector; uses packets.

For the purpose of this addon, a `bag` is: "safe", "storage", "locker", "satchel", "sack", "case", "wardrobe". 

For commands that use a filename, if one is not specified, it defaults to Name_JOB.lua, e.g., Rooks_PLD.lua
For commands that specify a bag, if one is not specified, it defaults to all, and will cycle through all of them.

The addon command is `org`, so `org freeze` will freeze, etc.

This utility is still in development and there are at least a couple of known issues (it does not always move out gear that is currently equipped, argument parsing could be better). It is designed to work simplest as a snapshotting utility (freeze and organize without arugments), but it should work no matter what you want to do with it.

### Settings

#### auto_heal
Automatically /heal after getting/storing gear.

#### bag_priority
The order that bags will be looked in for requested gear.

#### dump_bags
The order that bags will be used to move off unwanted gear, if not specified.

#### item_delay
A delay, in seconds, between item storage/retrieval. Defaults to 0 (no delay)


### Commands

#### Freeze

```
freeze [filename]
```

Freezes the current contents of all bags to `filename` in the respective data directory. This effectively takes a snapshot of your inventory for that job.

#### Get

```
get [filename] [bag]
```

Attempts to move anything specified from `bag` to your current inventory, using `filename` as the basis.


#### Tidy

```
tidy [filename] [bag]
```

A reverse of get - it moves out anything that is not specified.

#### Organize

```
organize [filename] [bag]
```

A tidy and get in one operation. With no arguments, it will attempt to restore the entire snapshot in freeze.
