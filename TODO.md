# Now

## SQS Bridge (Mel)
The OBS bridge sucks, it's like a million files.  Figure out what the right shape is supposed to be, and make sure you update the OBS bridge to use it as well

The SQS bridge is where 'pure event affordances' should live.  Stuff that just listens to a queue, does logic to it, then writes 0 or more events to another topic or queue

## Twitch Chat Bridge (QA)

Publish Chat events as received from Twitch into the Event Pipeline

Consume Twitch Bridge Control events to turn the bridge on / off

Consume Twitch Chat events from the Event Pipeline to populate Redis with last N chat messages

[redis API docs](https://redis.io/docs/latest/commands/redis-8-6-commands/)

    redis.lpush("recent_twitch_chat", payload)
    redis.ltrim("recent_twitch_chat", 0, 5)

Probably also keep a list of seen nicknames?

## Twitch Chat Renderer (QA)
Make a Hotwire-enabled screen to render chat as a web page with the thought to make a web source out of it later

We probably want to support twitch emoji and put at least a little thought into support the 7-whatever emoji's too

These will be important from the obs-bridge for the hotwire technique

[obs_bridges/show.html.erb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/app/views/admin/obs_bridges/show.html.erb#L46)
[obs_bridges/_status_panel.html.erb](https://github.com/meleneth/orinoco/blob/main/railsapp/app/views/admin/obs_bridges/_status_panel.html.erb)
[services/obs_bridge/status_broadcaster.rb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/app/services/obs_bridge/status_broadcaster.rb#L11)

# Soon

## Make Event Capturing Work
The bridge has something for 'capture the next 15 minutes', but it doesn't work.  We need to store events in redis for debugging purposes when it is enabled

## Use mermaid.js to make a diagram of the event pipeline
As the event pipeline gets more complicated and especially has user-generated entries, being able to see the shape of the configured pipelines will be important.

## Web UI to configure the ClipShow affordance
right now we're just using [script/dev/seed_clipshow.rb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/script/dev/seed_clipshow.rb) to configure ClipShow manually to be active against the 'Clips' scene.  We need a web UI, that should list the scenes and have checkboxes for which scenes should have ClipShow enabled.

Having ClipShow enabled means that when the system sees an event for media playback completed, it will disable the media source.

## Make ClipShow disable the media source before enabling it to play
if something goes wrong and a media source is left enabled, it will not play when we try so disable it first, then enable it to play

## Make a Discord Bridge
This might be difficult due to the need to securely store and access a secret

## figure out which twitch integration library to use - [http://rubygems.org](http://rubygems.org), search for twitch

## follow the Hotwire example to get an Overlay going
we use Hotwire currently for the OBS bridge control status panel

the overlay should be user-configured, but able to show dynamic information.

It's ok to start simple here.  'the overlay' being a page with a transparent background and a single div with some text on it will go a long, long way.  Or maybe the first one is the chat from twitch, who knows.

the point is to use this as a browser source in the OBS config itself.  Bonus points if we can add and configure the source without making the user do it.

## enumerate (and save in the database?) the known event types for the various bridges
we will want to maintain a master list of events per-domain (i.e. obs, twitch, etc) so we can subscribe to them and also because we only want to let known event types pass

# Later

## Fix 'which OBS to connect to' story
the config we are storing in the database is not being used to connect to OBS.
It should be.  It should also work transparently when in a docker container, which requires talking to 
docker.host.local instead of localhost? or something like that

## Fix railsapp dev container
We should probaly just remove it from the docker compose until this is done.

That said, if we bind mount the railsapp into the container we might actually be able to run dev via the container, which would be a big win

## come up with an event configuration UI
What events in what domains we're subscribed to, and what events we want to send.

## trigger configuration UI
Streamer bot has it right that everything needs it's own configuration place, but lost the game in making the links be not-navigable

## event pipeline config
From the web page we'll want to be able to maintain what the pipeline looks like - what SNS queues are listening for events, and which SQS queues they publish the events to.  A lot of this should 'just work' because we're making things that require specific wiring, but we should be able to view the setup as well

## figure out if we care about multi user access
password sniffing is bad and encryption is tricky, but profiles is still a thing? devise ruby gem

## need a global kill switch for all the bridges in case the user doesn't want stuff running all the time
right now we can bring the one bridge we have up or down, but we need The Big Switch

# Done

## Create the OBS bridge
A long-running bridge process connects to OBS via obs-websocket and handles event-driven control of scenes and inputs. The event pipeline version is now functional, with a control queue to manage bridge lifecycle (start/stop) and a command queue for passing commands through to OBS.

The bridge can be started via:

    ./railsapp/bin/dev

or

    cd railsapp && ./dev.sh bridge


## be able to trigger clips to be able to play
Playback is triggered by sending events into the pipeline. The OBS bridge consumes these events and forwards them directly as obs-websocket requests (e.g., enabling the relevant scene item).

## be able to import clip names from an auto-discovered scene
Scene and input inventory is fetched from OBS and normalized into Redis, allowing ClipShow to enumerate available clip sources without manual configuration.


## make a Clipshow affordance for doing QA style clip management
The Clipshow affordance provides a purpose-built workflow for managing media clips in OBS scenes for QA-style operation. It is implemented using discovered OBS inventory data combined with event-driven control, allowing clips to be identified, triggered, and automatically cleaned up after playback.

There is currently no configuration UI. Running the following script seeds ClipShow for the `Clips` scene in OBS:

    ./r_dev runner script/dev/seed_clipshow.rb

## Integrate SNS / SQS via GoAWS (create the Event Pipeline)
The server is running, the OBS bridge is controllable (bridge up/down) and commandable (OBS commands).

[config/initializers/event_pipeline_config.rb](https://github.com/meleneth/orinoco/blob/158aebcbffdcd3546675be23ffa3dc0c62c76c9f/railsapp/config/initializers/event_pipeline_config.rb#L23)

## get rails site running via docker and foreman for all devs
The development environment is split between Docker-managed services and local process orchestration.

`./dc_dev up -d` starts required infrastructure (Postgres, Redis, GoAWS).  
`./railsapp/bin/dev` runs the Rails webserver, Tailwind watcher, and OBS bridge.

    ./dc_dev up -d
    ./railsapp/bin/dev


## compose.yml to configure docker compose to run rails, goaws, postgres
A unified Docker Compose setup defines the full local development stack, including Rails, GoAWS, and Postgres. This provides a reproducible environment for all developers and mirrors the production topology at a smaller scale.


## install rbenv and ruby - instructions in devsetup.md
Development environment setup is standardized through documented steps for installing `rbenv` and the required Ruby version. This ensures consistent runtime behavior across contributors and avoids system Ruby drift.
