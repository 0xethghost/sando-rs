use std::fs::OpenOptions;
use std::str::FromStr;

use colored::Colorize;
use dotenv::dotenv;
use ethers::prelude::*;
use eyre::Result;

use fern::colors::{Color, ColoredLevelConfig};

use sando_rs::{
    prelude::{sync_dex, AllPoolsInfo, Dex, Pool, PoolVariant},
    runner::Bot,
    utils::{self, dotenv::read_env_vars},
};

#[tokio::main]
async fn main() -> Result<()> {
    log::info!("Starting Bot Initialization");
    dotenv().ok();

    // setup logger configs
    let mut colors = ColoredLevelConfig::new();
    colors.trace = Color::Cyan;
    colors.debug = Color::Magenta;
    colors.info = Color::Green;
    colors.warn = Color::Red;
    colors.error = Color::BrightRed;

    // setup logging both to stdout and file
    fern::Dispatch::new()
        .format(move |out, message, record| {
            out.finish(format_args!(
                "{}[{}] {}",
                chrono::Local::now().format("[%H:%M:%S]"),
                colors.color(record.level()),
                message
            ))
        })
        .chain(std::io::stdout())
        .chain(fern::log_file("output.log")?)
        // hide all logs for everything other than bot
        .level(log::LevelFilter::Error)
        .level_for("sando_rs", log::LevelFilter::Info)
        .apply()?;

    read_env_vars();

    log::info!(
        "{}",
        format!("{}", utils::constants::get_banner().green().bold())
    );

    // Create the websocket client
    let client = utils::create_websocket_client().await.unwrap();

    ///////////////////////////////////////
    //  Setup all dexes and their pools  //
    ///////////////////////////////////////
    let mut dexes = vec![];

    // Add UniswapV2 pairs
    dexes.push(Dex::new(
        H160::from_str("0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f").unwrap(),
        PoolVariant::UniswapV2,
        10000835,
    ));

    //// Add Sushiswap pairs
    dexes.push(Dex::new(
        H160::from_str("0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac").unwrap(),
        PoolVariant::UniswapV2,
        10794229,
    ));

    //// Add CryptoCom-Swap pairs
    dexes.push(Dex::new(
        H160::from_str("0x9DEB29c9a4c7A88a3C0257393b7f3335338D9A9D").unwrap(),
        PoolVariant::UniswapV2,
        10828414,
    ));

    //// Add Convergence-Swap pairs
    dexes.push(Dex::new(
        H160::from_str("0x4eef5746ED22A2fD368629C1852365bf5dcb79f1").unwrap(),
        PoolVariant::UniswapV2,
        12385067,
    ));

    //// Add Pancake-Swap pairs
    dexes.push(Dex::new(
        H160::from_str("0x1097053Fd2ea711dad45caCcc45EfF7548fCB362").unwrap(),
        PoolVariant::UniswapV2,
        15614590,
    ));

    //// Add Shiba-Swap pairs, home of shitcoins
    dexes.push(Dex::new(
        H160::from_str("0x115934131916C8b277DD010Ee02de363c09d037c").unwrap(),
        PoolVariant::UniswapV2,
        12771526,
    ));

    //// Add Saitaswap pools
    dexes.push(Dex::new(
        H160::from_str("0x35113a300ca0D7621374890ABFEAC30E88f214b1").unwrap(),
        PoolVariant::UniswapV2,
        15210780,
    ));

    //// Add UniswapV3 pools
    dexes.push(Dex::new(
        H160::from_str("0x1F98431c8aD98523631AE4a59f267346ea31F984").unwrap(),
        PoolVariant::UniswapV3,
        12369621,
    ));
    
    //// Add Pancake v3 pools
    dexes.push(Dex::new(
        H160::from_str("0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9").unwrap(),
        PoolVariant::UniswapV3,
        16950672,
    ));

    //// Add Sushiswap v3 pools
    dexes.push(Dex::new(
        H160::from_str("0xbaceb8ec6b9355dfc0269c18bac9d6e2bdc29c4f").unwrap(),
        PoolVariant::UniswapV3,
        16955547,
    ));

    // let pools_from_file = utils::pools::get_pools_from_file();

    let mut start_block: Option<BlockNumber> = None;
    let mut all_pools: Vec<Pool> = vec![];

    // Open the file
    match OpenOptions::new()
        .read(true)
        .open("pools.json.zstd")
    {
        Ok(reader) => {
            // Wrap the file in the zstd decoder
            let reader = zstd::Decoder::new(reader)?;
            // Read the data from the decoder
            let all_pools_info: AllPoolsInfo = serde_json::from_reader(reader)?;
            let mut pools_from_file = all_pools_info.pools.clone();
            start_block = Some(BlockNumber::Number(all_pools_info.last_block_number));
            all_pools.append(&mut pools_from_file);
        }
        Err(e) => {
            println!("Couldn't read pools info from file due to {}", e);
        }
    };

    let current_block = client.get_block_number().await.unwrap();
    let mut pools = sync_dex(dexes.clone(), &client, current_block, start_block)
        .await
        .unwrap();
    all_pools.append(&mut pools);

    let data = AllPoolsInfo {
        last_block_number: current_block,
        pools: all_pools.clone(),
    };

    //// write pools to file
    // Open the file
    match OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open("pools.json.zstd")
    {
        Ok(writer) => {
            // Wrap the file in the zstd encoder
            if let Ok(encoder) = zstd::Encoder::new(writer, 0){
                let writer = encoder.auto_finish();
                // Write the data into the encoder
                serde_json::to_writer(writer, &data)?;
            };
        }
        Err(e) => {
            println!("Failed to write to pools file due to {}", e);
        }
    }

    log::info!("all_pools_len: {}", all_pools.len());

    // Execution loop (reconnect bot if it dies)
    loop {
        let client = utils::create_websocket_client().await.unwrap();
        let mut bot = Bot::new(client, all_pools.clone(), dexes.clone())
            .await
            .unwrap();

        bot.run().await.unwrap();
        log::error!("Websocket disconnected");
    }
}

//#[cfg(test)]
//mod test {
//    use ethers::providers::Middleware;
//    use futures::StreamExt;
//    use sando_rs::utils::testhelper;
//
//    #[tokio::test]
//    async fn sub_blocks() {
//        let client = testhelper::create_ws().await;
//        // let client = Provider::<Ws>::connect("ws://localhost:8545").await.unwrap();
//
//        let mut stream = client.subscribe_blocks().await.unwrap();
//        let mut prev = 0;
//        while let Some(block) = stream.next().await {
//            println!("{:#?}", block.timestamp.as_u32() - prev);
//            prev = block.timestamp.as_u32();
//        }
//    }
//}
