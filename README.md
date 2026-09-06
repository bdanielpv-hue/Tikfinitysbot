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
