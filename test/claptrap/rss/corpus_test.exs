defmodule Claptrap.RSS.CorpusTest do
  use ExUnit.Case, async: true

  # Fixture sources and rationale:
  #
  # minimal.xml        – Hand-crafted minimal valid feed; baseline with only required elements
  # full.xml           – Hand-crafted feed with every optional element populated; tests completeness
  # wordpress.xml      – WordPress-style blog feed; uses content:encoded, dc:creator, wfw:commentRss
  # podcast.xml        – Podcast feed; heavy use of <enclosure>, itunes:* namespace extensions
  # substack.xml       – Substack newsletter-style feed; uses atom:link self-reference, dc:creator
  # cdata_descriptions.xml – Feed with CDATA sections in descriptions; tests CDATA extraction
  # iso8601_dates.xml  – Feed using ISO 8601 dates instead of RFC 822
  # missing_link.xml   – Feed missing the <link> element entirely
  # items_before_metadata.xml – Feed where items appear before channel metadata

  alias Claptrap.RSS.{Category, Cloud, Enclosure, Feed, Guid, Image, Item, Source, TextInput}

  @fixtures_dir Path.join([__DIR__, "..", "..", "fixtures", "rss"])

  # ---------------------------------------------------------------------------
  # Auto-discovered parse tests
  # ---------------------------------------------------------------------------

  describe "corpus: all fixtures parse without error" do
    for file <- File.ls!(Path.join([__DIR__, "..", "..", "fixtures", "rss"])),
        Path.extname(file) == ".xml" do
      @tag fixture: file
      test "parses #{file} without error" do
        xml = File.read!(Path.join(@fixtures_dir, unquote(file)))
        assert {:ok, %Feed{}} = Claptrap.RSS.parse(xml)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Per-fixture holistic assertions
  # ---------------------------------------------------------------------------

  describe "minimal fixture" do
    test "parses to expected struct" do
      xml = File.read!(Path.join(@fixtures_dir, "minimal.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      assert feed == %Feed{
               title: "Minimal Feed",
               link: "https://example.com",
               description: "A minimal valid RSS 2.0 feed with only required elements",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: nil,
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [],
               namespaces: %{},
               extensions: %{}
             }
    end
  end

  describe "full fixture" do
    test "parses to expected struct with every optional field populated" do
      xml = File.read!(Path.join(@fixtures_dir, "full.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      assert feed == %Feed{
               title: "Full Example Feed",
               link: "https://example.com",
               description: "A feed with every optional channel and item element populated",
               language: "en-us",
               copyright: "Copyright 2024 Example Corp",
               managing_editor: "editor@example.com (Jane Editor)",
               web_master: "webmaster@example.com (Bob Admin)",
               pub_date: ~U[2024-06-01 10:00:00Z],
               last_build_date: ~U[2024-06-01 12:30:00Z],
               generator: "FullFeedGenerator 2.0",
               docs: "https://www.rssboard.org/rss-specification",
               ttl: 60,
               rating: "(PICS-1.1 \"http://www.classify.org/safesurf/\" 1 r (SS~~000 1))",
               cloud: %Cloud{
                 domain: "rpc.example.com",
                 port: 80,
                 path: "/RPC2",
                 register_procedure: "myCloud.rssPleaseNotify",
                 protocol: "xml-rpc"
               },
               image: %Image{
                 url: "https://example.com/logo.png",
                 title: "Example Logo",
                 link: "https://example.com",
                 width: 144,
                 height: 88,
                 description: "The Example Corp logo"
               },
               text_input: %TextInput{
                 title: "Search",
                 description: "Search this feed",
                 name: "q",
                 link: "https://example.com/search"
               },
               categories: [
                 %Category{value: "Technology", domain: nil},
                 %Category{value: "Elixir", domain: "https://example.com/cats"},
                 %Category{value: "Programming", domain: "https://example.com/cats"}
               ],
               skip_hours: [0, 1, 2, 3],
               skip_days: ["Saturday", "Sunday"],
               items: [
                 %Item{
                   title: "First Post: Getting Started",
                   link: "https://example.com/posts/first",
                   description: "An introduction to our new blog and what to expect.",
                   author: "author@example.com (Alice Writer)",
                   comments: "https://example.com/posts/first#comments",
                   pub_date: ~U[2024-05-31 08:00:00Z],
                   enclosure: %Enclosure{
                     url: "https://example.com/media/intro.mp3",
                     length: 5_120_000,
                     type: "audio/mpeg"
                   },
                   guid: %Guid{value: "https://example.com/posts/first", is_perma_link: true},
                   source: %Source{value: "Other Feed", url: "https://other.com/feed.xml"},
                   categories: [
                     %Category{value: "Introductions", domain: nil},
                     %Category{value: "Meta", domain: "https://example.com/cats"}
                   ],
                   extensions: %{
                     "http://purl.org/dc/elements/1.1/" => [
                       %{name: "creator", value: "Alice Writer", attrs: %{}}
                     ]
                   }
                 },
                 %Item{
                   title: "Second Post: Deep Dive",
                   link: "https://example.com/posts/second",
                   description: "A deeper look at the technical details behind Example Corp.",
                   author: "bob@example.com (Bob Developer)",
                   comments: "https://example.com/posts/second#comments",
                   pub_date: ~U[2024-06-01 09:00:00Z],
                   enclosure: nil,
                   guid: %Guid{
                     value: "urn:uuid:a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                     is_perma_link: false
                   },
                   source: nil,
                   categories: [%Category{value: "Technical", domain: nil}],
                   extensions: %{}
                 }
               ],
               namespaces: %{"dc" => "http://purl.org/dc/elements/1.1/"},
               extensions: %{}
             }
    end
  end

  describe "wordpress fixture" do
    test "parses to expected struct with namespace extensions" do
      xml = File.read!(Path.join(@fixtures_dir, "wordpress.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      # Capture long content:encoded values for readability
      assert %Feed{
               items: [
                 %Item{extensions: %{"http://purl.org/rss/1.0/modules/content/" => [%{value: encoded_1}]}},
                 %Item{extensions: %{"http://purl.org/rss/1.0/modules/content/" => [%{value: encoded_2}]}}
               ]
             } = feed

      assert feed == %Feed{
               title: "WordPress Engineering Blog",
               link: "https://engineering.example.com",
               description: "Latest posts from the engineering team",
               language: "en-US",
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: ~U[2024-05-15 14:30:00Z],
               generator: "https://wordpress.org/?v=6.5.3",
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: %Image{
                 url: "https://engineering.example.com/wp-content/uploads/2024/01/favicon-32x32.png",
                 title: "WordPress Engineering Blog",
                 link: "https://engineering.example.com",
                 width: 32,
                 height: 32,
                 description: nil
               },
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Scaling Our Elixir Infrastructure",
                   link: "https://engineering.example.com/2024/05/scaling-elixir/",
                   description: "How we scaled our Elixir services to handle 10x traffic growth.",
                   author: nil,
                   comments: "https://engineering.example.com/2024/05/scaling-elixir/#respond",
                   pub_date: ~U[2024-05-15 14:30:00Z],
                   enclosure: nil,
                   guid: %Guid{
                     value: "https://engineering.example.com/?p=1042",
                     is_perma_link: false
                   },
                   source: nil,
                   categories: [
                     %Category{value: "Engineering", domain: nil},
                     %Category{value: "Elixir", domain: nil},
                     %Category{value: "Infrastructure", domain: nil}
                   ],
                   extensions: %{
                     "http://purl.org/dc/elements/1.1/" => [
                       %{name: "creator", value: "Sarah Chen", attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/content/" => [
                       %{name: "encoded", value: encoded_1, attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/slash/" => [
                       %{name: "comments", value: "12", attrs: %{}}
                     ],
                     "http://wellformedweb.org/CommentAPI/" => [
                       %{
                         name: "commentRss",
                         value: "https://engineering.example.com/2024/05/scaling-elixir/feed/",
                         attrs: %{}
                       }
                     ]
                   }
                 },
                 %Item{
                   title: "Introducing Our New CI Pipeline",
                   link: "https://engineering.example.com/2024/05/new-ci-pipeline/",
                   description: "A walkthrough of our new continuous integration setup.",
                   author: nil,
                   comments: "https://engineering.example.com/2024/05/new-ci-pipeline/#respond",
                   pub_date: ~U[2024-05-13 09:00:00Z],
                   enclosure: nil,
                   guid: %Guid{
                     value: "https://engineering.example.com/?p=1038",
                     is_perma_link: false
                   },
                   source: nil,
                   categories: [
                     %Category{value: "DevOps", domain: nil},
                     %Category{value: "CI/CD", domain: nil}
                   ],
                   extensions: %{
                     "http://purl.org/dc/elements/1.1/" => [
                       %{name: "creator", value: "Marcus Johnson", attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/content/" => [
                       %{name: "encoded", value: encoded_2, attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/slash/" => [
                       %{name: "comments", value: "5", attrs: %{}}
                     ],
                     "http://wellformedweb.org/CommentAPI/" => [
                       %{
                         name: "commentRss",
                         value: "https://engineering.example.com/2024/05/new-ci-pipeline/feed/",
                         attrs: %{}
                       }
                     ]
                   }
                 }
               ],
               namespaces: %{
                 "atom" => "http://www.w3.org/2005/Atom",
                 "content" => "http://purl.org/rss/1.0/modules/content/",
                 "dc" => "http://purl.org/dc/elements/1.1/",
                 "slash" => "http://purl.org/rss/1.0/modules/slash/",
                 "sy" => "http://purl.org/rss/1.0/modules/syndication/",
                 "wfw" => "http://wellformedweb.org/CommentAPI/"
               },
               extensions: %{
                 "http://purl.org/rss/1.0/modules/syndication/" => [
                   %{name: "updatePeriod", value: "hourly", attrs: %{}},
                   %{name: "updateFrequency", value: "1", attrs: %{}}
                 ],
                 "http://www.w3.org/2005/Atom" => [
                   %{
                     name: "link",
                     value: nil,
                     attrs: %{
                       "href" => "https://engineering.example.com/feed/",
                       "rel" => "self",
                       "type" => "application/rss+xml"
                     }
                   }
                 ]
               }
             }

      assert encoded_1 =~ "distributed supervision tree"
      assert encoded_2 =~ "CI pipeline to reduce build times"
    end
  end

  describe "podcast fixture" do
    test "parses to expected struct with enclosures and itunes extensions" do
      xml = File.read!(Path.join(@fixtures_dir, "podcast.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      # Capture the one long content:encoded value
      assert %Feed{
               items: [
                 %Item{
                   extensions: %{"http://purl.org/rss/1.0/modules/content/" => [%{value: encoded_ep142}]}
                 },
                 _,
                 _
               ]
             } = feed

      assert feed == %Feed{
               title: "The Elixir Podcast",
               link: "https://elixirpodcast.example.com",
               description: "Weekly conversations about Elixir, Erlang, and the BEAM ecosystem",
               language: "en-us",
               copyright: "\u00A9 2024 Elixir Podcast Network",
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: ~U[2024-06-06 05:00:00Z],
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: %Image{
                 url: "https://elixirpodcast.example.com/artwork-3000.jpg",
                 title: "The Elixir Podcast",
                 link: "https://elixirpodcast.example.com",
                 width: nil,
                 height: nil,
                 description: nil
               },
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Episode 142: LiveView 1.0 Deep Dive",
                   link: "https://elixirpodcast.example.com/episodes/142",
                   description:
                     "We sit down with Chris McCord to discuss the LiveView 1.0 release, what changed, and what the future holds.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-06 05:00:00Z],
                   enclosure: %Enclosure{
                     url: "https://cdn.elixirpodcast.example.com/episodes/ep142-liveview-deep-dive.mp3",
                     length: 67_108_864,
                     type: "audio/mpeg"
                   },
                   guid: %Guid{value: "ep142-liveview-1-0", is_perma_link: false},
                   source: nil,
                   categories: [],
                   extensions: %{
                     "http://purl.org/rss/1.0/modules/content/" => [
                       %{name: "encoded", value: encoded_ep142, attrs: %{}}
                     ],
                     "http://www.itunes.com/dtds/podcast-1.0.dtd" => [
                       %{name: "title", value: "LiveView 1.0 Deep Dive", attrs: %{}},
                       %{name: "episode", value: "142", attrs: %{}},
                       %{name: "season", value: "5", attrs: %{}},
                       %{name: "duration", value: "01:12:45", attrs: %{}},
                       %{name: "explicit", value: "false", attrs: %{}},
                       %{name: "episodeType", value: "full", attrs: %{}},
                       %{
                         name: "image",
                         value: nil,
                         attrs: %{
                           "href" => "https://elixirpodcast.example.com/episodes/ep142-artwork.jpg"
                         }
                       }
                     ]
                   }
                 },
                 %Item{
                   title: "Episode 141: Building Distributed Systems with Horde",
                   link: "https://elixirpodcast.example.com/episodes/141",
                   description:
                     "Exploring distributed process management in Elixir using Horde for dynamic supervisors and registries.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-05-30 05:00:00Z],
                   enclosure: %Enclosure{
                     url: "https://cdn.elixirpodcast.example.com/episodes/ep141-horde.mp3",
                     length: 52_428_800,
                     type: "audio/mpeg"
                   },
                   guid: %Guid{value: "ep141-distributed-horde", is_perma_link: false},
                   source: nil,
                   categories: [],
                   extensions: %{
                     "http://www.itunes.com/dtds/podcast-1.0.dtd" => [
                       %{
                         name: "title",
                         value: "Building Distributed Systems with Horde",
                         attrs: %{}
                       },
                       %{name: "episode", value: "141", attrs: %{}},
                       %{name: "season", value: "5", attrs: %{}},
                       %{name: "duration", value: "00:58:30", attrs: %{}},
                       %{name: "explicit", value: "false", attrs: %{}},
                       %{name: "episodeType", value: "full", attrs: %{}}
                     ]
                   }
                 },
                 %Item{
                   title: "Episode 140: Bonus - OTP 27 Release Notes",
                   link: "https://elixirpodcast.example.com/episodes/140",
                   description: "A quick bonus episode covering the highlights of the OTP 27 release.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-05-25 12:00:00Z],
                   enclosure: %Enclosure{
                     url: "https://cdn.elixirpodcast.example.com/episodes/ep140-otp27.mp3",
                     length: 15_728_640,
                     type: "audio/mpeg"
                   },
                   guid: %Guid{value: "ep140-otp27-bonus", is_perma_link: false},
                   source: nil,
                   categories: [],
                   extensions: %{
                     "http://www.itunes.com/dtds/podcast-1.0.dtd" => [
                       %{name: "title", value: "OTP 27 Release Notes", attrs: %{}},
                       %{name: "episode", value: "140", attrs: %{}},
                       %{name: "duration", value: "00:22:15", attrs: %{}},
                       %{name: "explicit", value: "false", attrs: %{}},
                       %{name: "episodeType", value: "bonus", attrs: %{}}
                     ]
                   }
                 }
               ],
               namespaces: %{
                 "atom" => "http://www.w3.org/2005/Atom",
                 "content" => "http://purl.org/rss/1.0/modules/content/",
                 "itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd"
               },
               extensions: %{
                 "http://www.itunes.com/dtds/podcast-1.0.dtd" => [
                   %{name: "author", value: "Elixir Podcast Network", attrs: %{}},
                   %{
                     name: "summary",
                     value:
                       "Weekly conversations about Elixir, Erlang, and the BEAM ecosystem. Interviews with library authors, core team members, and production users.",
                     attrs: %{}
                   },
                   %{
                     name: "owner",
                     value: [
                       %{name: "name", value: "Elixir Podcast Network", attrs: %{}},
                       %{name: "email", value: "hello@elixirpodcast.example.com", attrs: %{}}
                     ],
                     attrs: %{}
                   },
                   %{name: "explicit", value: "false", attrs: %{}},
                   %{name: "category", value: nil, attrs: %{"text" => "Technology"}},
                   %{
                     name: "image",
                     value: nil,
                     attrs: %{
                       "href" => "https://elixirpodcast.example.com/artwork-3000.jpg"
                     }
                   },
                   %{name: "type", value: "episodic", attrs: %{}}
                 ],
                 "http://www.w3.org/2005/Atom" => [
                   %{
                     name: "link",
                     value: nil,
                     attrs: %{
                       "href" => "https://elixirpodcast.example.com/feed.xml",
                       "rel" => "self",
                       "type" => "application/rss+xml"
                     }
                   }
                 ]
               }
             }

      assert encoded_ep142 =~ "LiveView 1.0 release"
    end
  end

  describe "substack fixture" do
    test "parses to expected struct with atom:link and dc:creator" do
      xml = File.read!(Path.join(@fixtures_dir, "substack.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      # Capture long content:encoded and description values
      assert %Feed{
               items: [
                 %Item{
                   description: desc_1,
                   extensions: %{
                     "http://purl.org/rss/1.0/modules/content/" => [%{value: encoded_1}]
                   }
                 },
                 %Item{
                   extensions: %{
                     "http://purl.org/rss/1.0/modules/content/" => [%{value: encoded_2}]
                   }
                 }
               ]
             } = feed

      assert feed == %Feed{
               title: "The BEAM Weekly",
               link: "https://beamweekly.substack.com",
               description: "A weekly newsletter covering the Erlang and Elixir ecosystem",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: ~U[2024-06-07 12:05:33Z],
               generator: "Substack",
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: %Image{
                 url:
                   "https://substackcdn.com/image/fetch/w_256,c_limit,f_auto,q_auto:good,fl_progressive:steep/https%3A%2F%2Fsubstack-post-media.s3.amazonaws.com%2Fpublic%2Fimages%2Fbeam-logo.png",
                 title: "The BEAM Weekly",
                 link: "https://beamweekly.substack.com",
                 width: nil,
                 height: nil,
                 description: nil
               },
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Issue #87: Erlang/OTP 27 Highlights",
                   link: "https://beamweekly.substack.com/p/issue-87-erlangotp-27-highlights",
                   description: desc_1,
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-07 12:05:33Z],
                   enclosure: %Enclosure{
                     url:
                       "https://substackcdn.com/image/fetch/f_auto,q_auto:good,fl_progressive:steep/https%3A%2F%2Fsubstack-post-media.s3.amazonaws.com%2Fpublic%2Fimages%2Fotp27-cover.png",
                     length: 0,
                     type: "image/png"
                   },
                   guid: %Guid{
                     value: "https://beamweekly.substack.com/p/issue-87-erlangotp-27-highlights",
                     is_perma_link: true
                   },
                   source: nil,
                   categories: [],
                   extensions: %{
                     "http://purl.org/dc/elements/1.1/" => [
                       %{name: "creator", value: "BEAM Weekly Team", attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/content/" => [
                       %{name: "encoded", value: encoded_1, attrs: %{}}
                     ]
                   }
                 },
                 %Item{
                   title: "Issue #86: LiveView Turns Five",
                   link: "https://beamweekly.substack.com/p/issue-86-liveview-turns-five",
                   description:
                     "<p>Celebrating five years of Phoenix LiveView and looking at how far the library has come.</p>",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-05-31 12:01:22Z],
                   enclosure: nil,
                   guid: %Guid{
                     value: "https://beamweekly.substack.com/p/issue-86-liveview-turns-five",
                     is_perma_link: true
                   },
                   source: nil,
                   categories: [],
                   extensions: %{
                     "http://purl.org/dc/elements/1.1/" => [
                       %{name: "creator", value: "BEAM Weekly Team", attrs: %{}}
                     ],
                     "http://purl.org/rss/1.0/modules/content/" => [
                       %{name: "encoded", value: encoded_2, attrs: %{}}
                     ]
                   }
                 }
               ],
               namespaces: %{
                 "atom" => "http://www.w3.org/2005/Atom",
                 "content" => "http://purl.org/rss/1.0/modules/content/",
                 "dc" => "http://purl.org/dc/elements/1.1/"
               },
               extensions: %{
                 "http://www.w3.org/2005/Atom" => [
                   %{
                     name: "link",
                     value: nil,
                     attrs: %{
                       "href" => "https://beamweekly.substack.com/feed",
                       "rel" => "self",
                       "type" => "application/rss+xml"
                     }
                   }
                 ]
               }
             }

      assert desc_1 =~ "subscription-widget"
      assert encoded_1 =~ "Erlang/OTP 27 Highlights"
      assert encoded_2 =~ "ElixirConf 2019"
    end
  end

  describe "cdata_descriptions fixture" do
    test "parses to expected struct with CDATA content extracted cleanly" do
      xml = File.read!(Path.join(@fixtures_dir, "cdata_descriptions.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      # Capture the long HTML description for readability
      assert %Feed{items: [%Item{description: rich_html_desc} | _]} = feed

      assert feed == %Feed{
               title: "CDATA Example Feed",
               link: "https://cdata.example.com",
               description: "A feed where <em>all</em> descriptions use CDATA sections",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: nil,
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Rich HTML Description",
                   link: "https://cdata.example.com/posts/rich-html",
                   description: rich_html_desc,
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-03 10:00:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "Special Characters in CDATA",
                   link: "https://cdata.example.com/posts/special-chars",
                   description:
                     "Prices: $10 < $20 & $30 > $25. Use the formula: x = (a + b) * c / d. \"Quoted\" and 'single quoted' text.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-02 10:00:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "Empty CDATA",
                   link: "https://cdata.example.com/posts/empty",
                   description: nil,
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-01 10:00:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "CDATA Title Too",
                   link: "https://cdata.example.com/posts/cdata-title",
                   description: "<p>This item also has CDATA in the title element above, though that is uncommon.</p>",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-05-31 10:00:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 }
               ],
               namespaces: %{},
               extensions: %{}
             }

      assert rich_html_desc =~ "<strong>bold</strong>"
      assert rich_html_desc =~ "<em>italic</em>"
      refute rich_html_desc =~ "<![CDATA["
    end
  end

  describe "iso8601_dates fixture" do
    test "parses to expected struct with ISO 8601 dates converted to UTC" do
      xml = File.read!(Path.join(@fixtures_dir, "iso8601_dates.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      assert feed == %Feed{
               title: "ISO 8601 Date Feed",
               link: "https://iso-dates.example.com",
               description: "A feed that uses ISO 8601 dates instead of RFC 822",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: ~U[2024-06-01 12:00:00Z],
               last_build_date: ~U[2024-06-07 18:30:00Z],
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Post with ISO date",
                   link: "https://iso-dates.example.com/posts/1",
                   description: "This post uses an ISO 8601 formatted date.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-07 10:30:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "Post with offset ISO date",
                   link: "https://iso-dates.example.com/posts/2",
                   description: "This post uses an ISO 8601 date with timezone offset.",
                   author: nil,
                   comments: nil,
                   pub_date: ~U[2024-06-06 20:45:00Z],
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 }
               ],
               namespaces: %{},
               extensions: %{}
             }
    end
  end

  describe "missing_link fixture" do
    test "parses to expected struct with empty link in lenient mode" do
      xml = File.read!(Path.join(@fixtures_dir, "missing_link.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      assert feed == %Feed{
               title: "Feed Without Link",
               link: "",
               description: "This feed is missing the link element entirely",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: nil,
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Post One",
                   link: nil,
                   description: "A post in a feed that has no channel link.",
                   author: nil,
                   comments: nil,
                   pub_date: nil,
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "Post Two",
                   link: nil,
                   description: "Another post without a link.",
                   author: nil,
                   comments: nil,
                   pub_date: nil,
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 }
               ],
               namespaces: %{},
               extensions: %{}
             }
    end
  end

  describe "items_before_metadata fixture" do
    test "parses to expected struct despite items appearing before channel metadata" do
      xml = File.read!(Path.join(@fixtures_dir, "items_before_metadata.xml"))

      assert {:ok, feed} = Claptrap.RSS.parse(xml)

      assert feed == %Feed{
               title: "Quirky Feed",
               link: "https://quirky.example.com",
               description: "A feed where items appear before channel metadata",
               language: nil,
               copyright: nil,
               managing_editor: nil,
               web_master: nil,
               pub_date: nil,
               last_build_date: nil,
               generator: nil,
               docs: nil,
               ttl: nil,
               rating: nil,
               cloud: nil,
               image: nil,
               text_input: nil,
               categories: [],
               skip_hours: [],
               skip_days: [],
               items: [
                 %Item{
                   title: "Early Item One",
                   link: "https://quirky.example.com/1",
                   description: "This item appears before the channel title and link.",
                   author: nil,
                   comments: nil,
                   pub_date: nil,
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 },
                 %Item{
                   title: "Early Item Two",
                   link: "https://quirky.example.com/2",
                   description: "Another early item.",
                   author: nil,
                   comments: nil,
                   pub_date: nil,
                   enclosure: nil,
                   guid: nil,
                   source: nil,
                   categories: [],
                   extensions: %{}
                 }
               ],
               namespaces: %{},
               extensions: %{}
             }
    end
  end

  # ---------------------------------------------------------------------------
  # Roundtrip tests
  # ---------------------------------------------------------------------------

  describe "corpus: roundtrip parse -> generate -> reparse" do
    for file <- File.ls!(Path.join([__DIR__, "..", "..", "fixtures", "rss"])),
        Path.extname(file) == ".xml" do
      @tag fixture: file
      test "roundtrip #{file}" do
        xml = File.read!(Path.join(@fixtures_dir, unquote(file)))
        assert {:ok, %Feed{} = feed} = Claptrap.RSS.parse(xml)

        case Claptrap.RSS.generate(feed) do
          {:ok, regenerated_xml} ->
            assert {:ok, reparsed} = Claptrap.RSS.parse(regenerated_xml)
            assert reparsed == feed

          {:error, %Claptrap.RSS.GenerateError{reason: :not_implemented}} ->
            :ok
        end
      end
    end
  end
end
