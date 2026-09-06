TikFinity + Streamer.bot: Coin-Based TikTok Gift Sound Alerts

This setup creates TikTok LIVE gift sounds that:

Combine rapidly repeated gifts into a stack.
Keep different viewers' stacks separate.
Keep different gift types separate.
Total the coins in each stack.
Play only one sound when the stack finishes.
Choose a random sound based on the stack's total coin value.
Queue completed sounds so they do not play over each other.
Let you add/remove audio files without editing the code.
What you need

Install TikFinity and Streamer.bot on the same Windows PC.

TikFinity receives the TikTok LIVE events and passes the gift information to Streamer.bot. Streamer.bot handles the stacking, calculates the total, chooses the sound, and plays it.

Step 1 — Create the audio folders

This guide uses:

C:\streaming\audio

Create five folders inside it:

C:\streaming\audio\
│
├── 1\
├── 2-9\
├── 10-99\
├── 100-999\
└── 1000-plus\

The folders represent:

Total coins	Folder
1	1
2–9	2-9
10–99	10-99
100–999	100-999
1,000+	1000-plus

Put whatever sounds you want into each folder.

For example:

C:\streaming\audio\10-99\
    bruh.mp3
    waffles.mp3
    scream.wav
    levelup.mp3

The filenames don't matter. The script randomly selects one file from the appropriate folder.

Supported formats in our script are:

.mp3
.wav
.ogg
.m4a
Step 2 — Connect TikFinity to Streamer.bot

Open Streamer.bot.

Enable its built-in WebSocket Server under the Server/Clients settings.

This doesn't require writing any WebSocket code. TikFinity's Streamer.bot integration uses the connection to send events to Streamer.bot.

Then open TikFinity and find:

Setup → Streamer.bot Connection

Use the default connection settings unless you've previously changed Streamer.bot's server configuration.

Click Test Connection.

Make sure TikFinity reports a successful connection before continuing.

Step 3 — Create the Streamer.bot action

In Streamer.bot:

Actions & Queues → Actions

Create an Action named:

Gift Sounds
IMPORTANT: Turn Concurrent ON

The action should have:

Enabled:       ON
Concurrent:    ON
Random Action: OFF
Queue:         Default

Concurrent must be enabled.

This is necessary because multiple incoming gift events need to run simultaneously while the script determines whether they're part of a stack.

Don't disable concurrency just to prevent sounds from overlapping. The code handles audio queuing separately.

Step 4 — Add the C# code

Inside the Gift Sounds action, add:

Core → C# → Execute C# Code

Delete the default code and paste:

using System;
using System.IO;
using System.Threading;
using System.Collections.Generic;

public class CPHInline
{
    // Protect gift-stack data while multiple events run
    private static readonly object syncLock = new object();

    // Only allow one completed gift sound to play at a time
    private static readonly object audioLock = new object();

    // Running coin totals for each stack
    private static readonly Dictionary<string, int> totals =
        new Dictionary<string, int>();

    // Tracks newer events belonging to the same stack
    private static readonly Dictionary<string, int> versions =
        new Dictionary<string, int>();

    private static readonly Random random = new Random();


    public bool Execute()
    {
        // ---------------------------------------------------------
        // COINS
        // ---------------------------------------------------------

        if (!CPH.TryGetArg<int>("coins", out int coins))
        {
            CPH.LogWarn(
                "Gift Sounds: No 'coins' argument received."
            );

            return true;
        }


        // ---------------------------------------------------------
        // USER ID
        // ---------------------------------------------------------

        string userId = "unknown-user";

        if (!CPH.TryGetArg<string>("userId", out userId)
            || string.IsNullOrWhiteSpace(userId))
        {
            userId = "unknown-user";
        }


        // ---------------------------------------------------------
        // USERNAME
        // ---------------------------------------------------------

        string username = "unknown";

        if (!CPH.TryGetArg<string>("username", out username)
            || string.IsNullOrWhiteSpace(username))
        {
            username = "unknown";
        }


        // ---------------------------------------------------------
        // GIFT ID
        // ---------------------------------------------------------

        string giftId = "unknown-gift";

        if (!CPH.TryGetArg<string>("giftId", out giftId)
            || string.IsNullOrWhiteSpace(giftId))
        {
            giftId = "unknown-gift";
        }


        // ---------------------------------------------------------
        // GIFT NAME
        // ---------------------------------------------------------

        string giftName = "unknown-gift";

        if (!CPH.TryGetArg<string>("giftName", out giftName)
            || string.IsNullOrWhiteSpace(giftName))
        {
            giftName = "unknown-gift";
        }


        // ---------------------------------------------------------
        // UNIQUE STACK
        //
        // Same viewer + same gift = same stack.
        // Different viewer or different gift = separate stack.
        // ---------------------------------------------------------

        string stackKey =
            userId + "|" + giftId;


        int myVersion;


        // ---------------------------------------------------------
        // ADD COINS TO STACK
        // ---------------------------------------------------------

        lock (syncLock)
        {
            if (!totals.ContainsKey(stackKey))
                totals[stackKey] = 0;

            if (!versions.ContainsKey(stackKey))
                versions[stackKey] = 0;


            totals[stackKey] += coins;

            versions[stackKey]++;

            myVersion = versions[stackKey];


            CPH.LogInfo(
                $"Gift Sounds: " +
                $"User={username} | " +
                $"Gift={giftName} | " +
                $"GiftID={giftId} | " +
                $"+{coins} coin(s) | " +
                $"Running Total={totals[stackKey]}"
            );
        }


        // ---------------------------------------------------------
        // STACK TIMEOUT
        //
        // Wait 1.5 seconds for another matching gift.
        // ---------------------------------------------------------

        Thread.Sleep(1500);


        int totalCoins;


        // ---------------------------------------------------------
        // DETERMINE WHETHER STACK HAS FINISHED
        // ---------------------------------------------------------

        lock (syncLock)
        {
            if (!versions.ContainsKey(stackKey))
                return true;


            // A newer matching gift arrived.
            // Let its invocation handle the completed stack.
            if (versions[stackKey] != myVersion)
                return true;


            totalCoins =
                totals[stackKey];


            // Stack is finished
            totals.Remove(stackKey);
            versions.Remove(stackKey);
        }


        CPH.LogInfo(
            $"Gift Sounds: STACK FINISHED | " +
            $"User={username} | " +
            $"Gift={giftName} | " +
            $"Total={totalCoins} coins"
        );


        PlayGiftSound(
            totalCoins,
            username,
            giftName
        );


        return true;
    }


    // =============================================================
    // PLAY GIFT SOUND
    // =============================================================

    private void PlayGiftSound(
        int coins,
        string username,
        string giftName
    )
    {
        // CHANGE THIS if your audio folder is somewhere else
        string baseFolder =
            @"C:\streaming\audio";


        string folder;


        // ---------------------------------------------------------
        // SELECT COIN RANGE
        // ---------------------------------------------------------

        if (coins == 1)
        {
            folder =
                Path.Combine(baseFolder, "1");
        }
        else if (coins <= 9)
        {
            folder =
                Path.Combine(baseFolder, "2-9");
        }
        else if (coins <= 99)
        {
            folder =
                Path.Combine(baseFolder, "10-99");
        }
        else if (coins <= 999)
        {
            folder =
                Path.Combine(baseFolder, "100-999");
        }
        else
        {
            folder =
                Path.Combine(baseFolder, "1000-plus");
        }


        // ---------------------------------------------------------
        // VERIFY FOLDER
        // ---------------------------------------------------------

        if (!Directory.Exists(folder))
        {
            CPH.LogWarn(
                $"Gift Sounds: Folder not found: {folder}"
            );

            return;
        }


        // ---------------------------------------------------------
        // FIND AUDIO FILES
        // ---------------------------------------------------------

        string[] files =
            Directory.GetFiles(folder);


        string[] sounds =
            Array.FindAll(
                files,
                file =>
                {
                    string ext =
                        Path.GetExtension(file)
                        .ToLowerInvariant();


                    return
                        ext == ".mp3" ||
                        ext == ".wav" ||
                        ext == ".ogg" ||
                        ext == ".m4a";
                }
            );


        if (sounds.Length == 0)
        {
            CPH.LogWarn(
                $"Gift Sounds: No audio files found in {folder}"
            );

            return;
        }


        // ---------------------------------------------------------
        // PICK RANDOM SOUND
        // ---------------------------------------------------------

        string sound;


        lock (random)
        {
            sound =
                sounds[
                    random.Next(sounds.Length)
                ];
        }


        CPH.LogInfo(
            $"Gift Sounds: QUEUED | " +
            $"{username} | " +
            $"{giftName} | " +
            $"{coins} coins | " +
            $"{Path.GetFileName(sound)}"
        );


        // ---------------------------------------------------------
        // AUDIO QUEUE
        //
        // If another alert is playing, wait until it finishes.
        // ---------------------------------------------------------

        lock (audioLock)
        {
            CPH.LogInfo(
                $"Gift Sounds: PLAYING | " +
                $"{username} | " +
                $"{giftName} | " +
                $"{coins} coins | " +
                $"{Path.GetFileName(sound)}"
            );


            // true = wait until playback finishes
            CPH.PlaySound(
                sound,
                1.0f,
                true
            );
        }


        CPH.LogInfo(
            $"Gift Sounds: FINISHED | " +
            $"{Path.GetFileName(sound)}"
        );
    }
}

Click:

Save and Compile

Streamer.bot should report a successful compilation.

Step 5 — Create the TikFinity action

Open:

TikFinity → Actions & Events

Create a new TikFinity Action.

Select:

Streamer.bot Action

Choose:

Gift Sounds

Save the action.

Step 6 — Send gift events to the action

Create a TikFinity gift Event that catches your gifts and executes the new Streamer.bot action.

You only need one general gift event feeding the Streamer.bot action.

Don't create overlapping TikFinity rules such as:

Gift 1+ Coins
Gift 2+ Coins
Gift 10+ Coins
Gift 100+ Coins

for the sound tiers.

TikFinity's minimum-coin rules overlap. A 100-coin gift can satisfy several of them.

Our Streamer.bot code handles the ranges instead.

The flow should effectively be:

TikTok Gift
     ↓
TikFinity
     ↓
Gift Sounds
     ↓
Streamer.bot
     ↓
C# script
     ↓
Stack gifts
     ↓
Calculate total
     ↓
Choose folder
     ↓
Choose random sound
     ↓
Play
Step 7 — Why giftId and userId matter

TikFinity provides Streamer.bot with information such as:

userId
username
giftId
giftName
coins
repeatCount

This setup uses:

userId + giftId

as the stack identifier.

That means:

Viewer A → Rose x10
Viewer A → Different Gift x5
Viewer B → Rose x20

are three separate stacks, even when they're happening around the same time.

The different gift types won't accidentally get added together.

Step 8 — How a stack is detected

TikFinity may deliver a repeated gift as individual events:

Rose → 1 coin
Rose → 1 coin
Rose → 1 coin
Rose → 1 coin
Rose → 1 coin

Instead of immediately playing five sounds, Streamer.bot does:

1
↓
2
↓
3
↓
4
↓
5
↓
No matching gift for 1.5 seconds
↓
STACK FINISHED
↓
5 total coins

Five coins falls into:

C:\streaming\audio\2-9

Streamer.bot randomly selects one sound from that folder and plays it once.

Step 9 — Sounds don't overlap

Suppose three stacks finish:

Viewer A → 25 coins
Viewer B → 5 coins
Viewer C → 150 coins

The stack calculations can happen simultaneously.

The audio cannot.

Instead:

25-coin alert
     ↓
finishes
     ↓
5-coin alert
     ↓
finishes
     ↓
150-coin alert

That's why Concurrent stays ON while the code's audioLock controls playback.

Step 10 — Change the stack delay

This line:

Thread.Sleep(1500);

means:

Wait 1.5 seconds.

To use 2 seconds:

Thread.Sleep(2000);

To use 1 second:

Thread.Sleep(1000);

1.5 seconds is a good starting point.

Step 11 — Using a different audio location

Everyone does not have to use:

C:\streaming\audio

Find this line:

string baseFolder =
    @"C:\streaming\audio";

For example, someone could change it to:

string baseFolder =
    @"D:\TikTok Sounds";

They would then create:

D:\TikTok Sounds\1
D:\TikTok Sounds\2-9
D:\TikTok Sounds\10-99
D:\TikTok Sounds\100-999
D:\TikTok Sounds\1000-plus
Testing before going live

Start with at least one sound in every folder.

Test a single 1-coin gift first. It should wait about 1.5 seconds and play something from:

\1

Then test several repeated 1-coin gifts. For example, 15 rapidly repeated 1-coin events should produce:

15 total coins
      ↓
10-99
      ↓
ONE random sound

Then test two different gifts rapidly. They should be treated as separate stacks.

Finally, check:

Streamer.bot → Actions & Queues → Action History

You should see log entries showing the running total, completed stack, queued sound, playing sound, and finished sound.

One important limitation

This setup determines when a stack ends using 1.5 seconds of inactivity. giftId identifies the gift type; it isn't a unique ID for each individual combo session.

Therefore, if the same viewer sends the same gift twice within the 1.5-second window, the script treats those events as one stack.

For the setup we tested, that tradeoff is what allows repeated 1-coin TikFinity events to be reliably combined into one final sound.
