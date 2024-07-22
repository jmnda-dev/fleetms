# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Fleetms.Repo.insert!(%Fleetms.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

provider_org_attrs = %{
  "name" => "Fleetms",
  "phone" => "1234567890",
  "is_provider" => true
}

provider_user_attrs = %{
  "email" => "user@example.com",
  "password" => "passWORD1234@",
  "password_confirmation" => "passWORD1234@",
  "user_profile" => %{
    "contact" => %{
      "address" => "9972",
      "address2" => "Kaikorai Valley Road",
      "city" => "Hamilton"
    },
    "first_name" => "Jane",
    "last_name" => "Doe"
  }
}

initial_user =
  Fleetms.Accounts.User
  |> Ash.Changeset.for_create(
    :register_with_password,
    Map.put(provider_user_attrs, "organization", provider_org_attrs)
  )
  |> Ash.Changeset.set_context(%{private: %{ash_authentication?: true}})
  |> Ash.create!()
  |> Ash.load!(:organization)

actor = initial_user

users = [
  %{
    "email" => "superuser@fleetms.com",
    "password" => "passWORD1234@",
    "password_confirmation" => "passWORD1234@",
    "organization_id" => initial_user.organization_id,
    "roles" => [:admin],
    "user_profile" => %{
      "contact" => %{
        "address" => "9972",
        "address2" => "Kaikorai Valley Road",
        "city" => "Hamilton",
        "country" => "New Zealand",
        "home_phone" => "(078)-262-1637",
        "mobile" => "(645)-909-9702",
        "state" => "Taranaki"
      },
      "first_name" => "Super",
      "last_name" => "User",
      "date_of_birth" => "1948-12-22T02:57:33.643Z",
      "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
    }
  },
  %{
    "email" => "charlie.zhang@example.com",
    "password" => "passWORD1234@",
    "password_confirmation" => "passWORD1234@",
    "organization_id" => initial_user.organization_id,
    "roles" => [Enum.random(Fleetms.Enums.basic_user_roles())],
    "user_profile" => %{
      "contact" => %{
        "address" => "9972",
        "address2" => "Kaikorai Valley Road",
        "city" => "Hamilton",
        "country" => "New Zealand",
        "home_phone" => "(078)-262-1637",
        "mobile" => "(645)-909-9702",
        "state" => "Taranaki"
      },
      "first_name" => "Charlie",
      "last_name" => "Zhang",
      "date_of_birth" => "1948-12-22T02:57:33.643Z",
      "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
    }
  },
  %{
    "email" => "antonio.foster@example.com",
    "password" => "passWORD1234@",
    "password_confirmation" => "passWORD1234@",
    "organization_id" => initial_user.organization_id,
    "roles" => [:admin],
    "user_profile" => %{
      "contact" => %{
        "address" => "8577",
        "address2" => "Dogwood Ave",
        "city" => "Bathurst",
        "country" => "Australia",
        "home_phone" => "01-9499-3825",
        "mobile" => "0443-575-195",
        "state" => "Northern Territory"
      },
      "first_name" => "Antonio",
      "last_name" => "Foster",
      "date_of_birth" => "1970-04-10T22:56:33.673Z",
      "profile_photo" => "https://randomuser.me/api/portraits/med/men/68.jpg"
    }
  }
  # %{
  #   "email" => "sebastian.turner@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2776",
  #       "address2" => "Saint Aubyn Street",
  #       "city" => "Hamilton",
  #       "country" => "New Zealand",
  #       "home_phone" => "(535)-882-3584",
  #       "mobile" => "(510)-112-4134",
  #       "state" => "West Coast"
  #     },
  #     "first_name" => "Sebastian",
  #     "last_name" => "Turner",
  #     "date_of_birth" => "1975-12-16T14:39:22.910Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/78.jpg"
  #   }
  # },
  # %{
  #   "email" => "dileep.adiga@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4516",
  #       "address2" => "MG Rd Bangalore",
  #       "city" => "Panihati",
  #       "country" => "India",
  #       "home_phone" => "8644306970",
  #       "mobile" => "9755869147",
  #       "state" => "Kerala"
  #     },
  #     "first_name" => "Dileep",
  #     "last_name" => "Adiga",
  #     "date_of_birth" => "1960-06-01T18:20:06.953Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/40.jpg"
  #   }
  # },
  # %{
  #   "email" => "aubrey.bell@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5607",
  #       "address2" => "Brown Terrace",
  #       "city" => "Albury",
  #       "country" => "Australia",
  #       "home_phone" => "09-0823-9244",
  #       "mobile" => "0400-257-558",
  #       "state" => "Northern Territory"
  #     },
  #     "first_name" => "Aubrey",
  #     "last_name" => "Bell",
  #     "date_of_birth" => "1958-02-25T01:55:40.949Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/1.jpg"
  #   }
  # },
  # %{
  #   "email" => "oya.abadan@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7807",
  #       "address2" => "Kushimoto Sk",
  #       "city" => "Malatya",
  #       "country" => "Turkey",
  #       "home_phone" => "(507)-447-4161",
  #       "mobile" => "(660)-206-0629",
  #       "state" => "Nevşehir"
  #     },
  #     "first_name" => "Oya",
  #     "last_name" => "Abadan",
  #     "date_of_birth" => "1978-03-26T22:10:33.955Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/89.jpg"
  #   }
  # },
  # %{
  #   "email" => "meral.ozbir@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3410",
  #       "address2" => "Maçka Cd",
  #       "city" => "Kırklareli",
  #       "country" => "Turkey",
  #       "home_phone" => "(848)-859-3779",
  #       "mobile" => "(920)-822-6736",
  #       "state" => "Karaman"
  #     },
  #     "first_name" => "Meral",
  #     "last_name" => "Özbir",
  #     "date_of_birth" => "1973-03-31T14:34:36.603Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/20.jpg"
  #   }
  # },
  # %{
  #   "email" => "julio.deschamps@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5835",
  #       "address2" => "Rue Principale",
  #       "city" => "Rougemont",
  #       "country" => "Switzerland",
  #       "home_phone" => "078 117 28 83",
  #       "mobile" => "077 220 95 95",
  #       "state" => "Neuchâtel"
  #     },
  #     "first_name" => "Julio",
  #     "last_name" => "Deschamps",
  #     "date_of_birth" => "1963-08-25T02:35:04.910Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/12.jpg"
  #   }
  # },
  # %{
  #   "email" => "philippe.sirko@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4575",
  #       "address2" => "Coastal Highway",
  #       "city" => "Cornwall",
  #       "country" => "Canada",
  #       "home_phone" => "D24 D05-8219",
  #       "mobile" => "G59 V99-3709",
  #       "state" => "British Columbia"
  #     },
  #     "first_name" => "Philippe",
  #     "last_name" => "Sirko",
  #     "date_of_birth" => "1982-03-04T22:35:26.700Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/44.jpg"
  #   }
  # },
  # %{
  #   "email" => "katie.griffin@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8057",
  #       "address2" => "Photinia Ave",
  #       "city" => "Kansas City",
  #       "country" => "United States",
  #       "home_phone" => "(752) 241-4450",
  #       "mobile" => "(324) 726-1248",
  #       "state" => "West Virginia"
  #     },
  #     "first_name" => "Katie",
  #     "last_name" => "Griffin",
  #     "date_of_birth" => "1994-04-24T03:23:50.288Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/28.jpg"
  #   }
  # },
  # %{
  #   "email" => "eeli.palo@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8885",
  #       "address2" => "Rautatienkatu",
  #       "city" => "Nousiainen",
  #       "country" => "Finland",
  #       "home_phone" => "02-909-995",
  #       "mobile" => "043-167-55-97",
  #       "state" => "Pirkanmaa"
  #     },
  #     "first_name" => "Eeli",
  #     "last_name" => "Palo",
  #     "date_of_birth" => "1955-06-07T19:18:35.770Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/92.jpg"
  #   }
  # },
  # %{
  #   "email" => "ashley.white@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2579",
  #       "address2" => "Park Lane",
  #       "city" => "St Albans",
  #       "country" => "United Kingdom",
  #       "home_phone" => "016973 41182",
  #       "mobile" => "07921 746203",
  #       "state" => "County Antrim"
  #     },
  #     "first_name" => "Ashley",
  #     "last_name" => "White",
  #     "date_of_birth" => "1971-05-17T20:10:34.571Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/39.jpg"
  #   }
  # },
  # %{
  #   "email" => "angela.young@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3489",
  #       "address2" => "Park Road",
  #       "city" => "Derby",
  #       "country" => "United Kingdom",
  #       "home_phone" => "015396 90904",
  #       "mobile" => "07921 406770",
  #       "state" => "County Down"
  #     },
  #     "first_name" => "Angela",
  #     "last_name" => "Young",
  #     "date_of_birth" => "1963-11-12T12:22:34.863Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/38.jpg"
  #   }
  # },
  # %{
  #   "email" => "dominic.chan@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3988",
  #       "address2" => "Arctic Way",
  #       "city" => "South River",
  #       "country" => "Canada",
  #       "home_phone" => "T27 B46-6589",
  #       "mobile" => "Q50 Y39-3327",
  #       "state" => "Northwest Territories"
  #     },
  #     "first_name" => "Dominic",
  #     "last_name" => "Chan",
  #     "date_of_birth" => "1995-02-16T20:42:40.743Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/98.jpg"
  #   }
  # },
  # %{
  #   "email" => "perla.narvaez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5163",
  #       "address2" => "Andador Coahuila de Zaragoza",
  #       "city" => "El Chote",
  #       "country" => "Mexico",
  #       "home_phone" => "(650) 225 3850",
  #       "mobile" => "(666) 472 5065",
  #       "state" => "Morelos"
  #     },
  #     "first_name" => "Perla",
  #     "last_name" => "Narváez",
  #     "date_of_birth" => "1978-08-23T01:25:04.738Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/71.jpg"
  #   }
  # },
  # %{
  #   "email" => "mechislava.zamora@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7989",
  #       "address2" => "Oleksandrivskiy prospekt",
  #       "city" => "Burin",
  #       "country" => "Ukraine",
  #       "home_phone" => "(097) V81-4104",
  #       "mobile" => "(098) S56-2601",
  #       "state" => "Kiyivska"
  #     },
  #     "first_name" => "Mechislava",
  #     "last_name" => "Zamora",
  #     "date_of_birth" => "1972-03-15T02:49:10.874Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/62.jpg"
  #   }
  # },
  # %{
  #   "email" => "perica.tadic@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5532",
  #       "address2" => "Slavka Subotića",
  #       "city" => "Prijepolje",
  #       "country" => "Serbia",
  #       "home_phone" => "010-8658-806",
  #       "mobile" => "069-1419-432",
  #       "state" => "Pirot"
  #     },
  #     "first_name" => "Perica",
  #     "last_name" => "Tadić",
  #     "date_of_birth" => "1989-10-01T00:59:27.924Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
  #   }
  # },
  # %{
  #   "email" => "armyn.rdyyn@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5757",
  #       "address2" => "جمال الدین اسدآبادی",
  #       "city" => "پاکدشت",
  #       "country" => "Iran",
  #       "home_phone" => "006-38059600",
  #       "mobile" => "0917-139-3624",
  #       "state" => "سیستان و بلوچستان"
  #     },
  #     "first_name" => "آرمین",
  #     "last_name" => "رضاییان",
  #     "date_of_birth" => "1954-03-04T01:35:48.461Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/15.jpg"
  #   }
  # },
  # %{
  #   "email" => "laura.rasmussen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6117",
  #       "address2" => "Vejlevej",
  #       "city" => "Kongens  Lyngby",
  #       "country" => "Denmark",
  #       "home_phone" => "34396324",
  #       "mobile" => "80761821",
  #       "state" => "Sjælland"
  #     },
  #     "first_name" => "Laura",
  #     "last_name" => "Rasmussen",
  #     "date_of_birth" => "1974-03-14T01:40:28.993Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/38.jpg"
  #   }
  # },
  # %{
  #   "email" => "matteus.nesheim@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7512",
  #       "address2" => "Diriks' gate",
  #       "city" => "Ekeberg",
  #       "country" => "Norway",
  #       "home_phone" => "84156296",
  #       "mobile" => "41822110",
  #       "state" => "Oslo"
  #     },
  #     "first_name" => "Matteus",
  #     "last_name" => "Nesheim",
  #     "date_of_birth" => "1999-10-30T09:19:30.502Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/90.jpg"
  #   }
  # },
  # %{
  #   "email" => "jerry.hernandez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3451",
  #       "address2" => "Albert Road",
  #       "city" => "Sheffield",
  #       "country" => "United Kingdom",
  #       "home_phone" => "015242 86593",
  #       "mobile" => "07506 501109",
  #       "state" => "Greater Manchester"
  #     },
  #     "first_name" => "Jerry",
  #     "last_name" => "Hernandez",
  #     "date_of_birth" => "1953-04-22T22:46:17.814Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/19.jpg"
  #   }
  # },
  # %{
  #   "email" => "dennis.hernaes@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9313",
  #       "address2" => "Kringveien",
  #       "city" => "Brandal",
  #       "country" => "Norway",
  #       "home_phone" => "25364384",
  #       "mobile" => "47327028",
  #       "state" => "Oslo"
  #     },
  #     "first_name" => "Dennis",
  #     "last_name" => "Hernæs",
  #     "date_of_birth" => "1980-09-23T07:36:14.559Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/34.jpg"
  #   }
  # },
  # %{
  #   "email" => "elusa.costa@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3537",
  #       "address2" => "Rua Pernambuco ",
  #       "city" => "Natal",
  #       "country" => "Brazil",
  #       "home_phone" => "(58) 4668-9648",
  #       "mobile" => "(86) 1755-0572",
  #       "state" => "Santa Catarina"
  #     },
  #     "first_name" => "Elusa",
  #     "last_name" => "Costa",
  #     "date_of_birth" => "1993-07-27T18:59:27.599Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/29.jpg"
  #   }
  # },
  # %{
  #   "email" => "emily.french@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1154",
  #       "address2" => "3rd St",
  #       "city" => "Chelsea",
  #       "country" => "Canada",
  #       "home_phone" => "P13 E49-7186",
  #       "mobile" => "R92 W30-9702",
  #       "state" => "Alberta"
  #     },
  #     "first_name" => "Emily",
  #     "last_name" => "French",
  #     "date_of_birth" => "1991-04-24T22:02:06.628Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/0.jpg"
  #   }
  # },
  # %{
  #   "email" => "christina.watson@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8959",
  #       "address2" => "Westheimer Rd",
  #       "city" => "Concord",
  #       "country" => "United States",
  #       "home_phone" => "(709) 521-0877",
  #       "mobile" => "(777) 910-3796",
  #       "state" => "Utah"
  #     },
  #     "first_name" => "Christina",
  #     "last_name" => "Watson",
  #     "date_of_birth" => "1947-12-16T14:54:54.536Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/36.jpg"
  #   }
  # },
  # %{
  #   "email" => "mhmdmyn.aalyzdh@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5133",
  #       "address2" => "آذربایجان",
  #       "city" => "شیراز",
  #       "country" => "Iran",
  #       "home_phone" => "067-43998833",
  #       "mobile" => "0915-507-1997",
  #       "state" => "بوشهر"
  #     },
  #     "first_name" => "محمدامين",
  #     "last_name" => "علیزاده",
  #     "date_of_birth" => "1973-04-03T07:18:52.521Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/31.jpg"
  #   }
  # },
  # %{
  #   "email" => "zakia.olieman@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "47",
  #       "address2" => "Boterkampweg",
  #       "city" => "Rijssen-Holten",
  #       "country" => "Netherlands",
  #       "home_phone" => "(0623) 232426",
  #       "mobile" => "(06) 82210671",
  #       "state" => "Limburg"
  #     },
  #     "first_name" => "Zakia",
  #     "last_name" => "Olieman",
  #     "date_of_birth" => "1945-02-27T02:18:25.580Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/62.jpg"
  #   }
  # },
  # %{
  #   "email" => "oona.manner@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4295",
  #       "address2" => "Tahmelantie",
  #       "city" => "Punkaharju",
  #       "country" => "Finland",
  #       "home_phone" => "07-237-846",
  #       "mobile" => "048-616-56-99",
  #       "state" => "Tavastia Proper"
  #     },
  #     "first_name" => "Oona",
  #     "last_name" => "Manner",
  #     "date_of_birth" => "1996-06-07T16:51:25.807Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/25.jpg"
  #   }
  # },
  # %{
  #   "email" => "alex.brooks@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5099",
  #       "address2" => "Karen Dr",
  #       "city" => "Miami",
  #       "country" => "United States",
  #       "home_phone" => "(663) 546-2872",
  #       "mobile" => "(648) 439-8980",
  #       "state" => "New Hampshire"
  #     },
  #     "first_name" => "Alex",
  #     "last_name" => "Brooks",
  #     "date_of_birth" => "1993-08-18T09:13:55.143Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/0.jpg"
  #   }
  # },
  # %{
  #   "email" => "sandra.halden@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6151",
  #       "address2" => "Vestre Holmen vei",
  #       "city" => "Glomstein",
  #       "country" => "Norway",
  #       "home_phone" => "84732382",
  #       "mobile" => "96334368",
  #       "state" => "Hordaland"
  #     },
  #     "first_name" => "Sandra",
  #     "last_name" => "Halden",
  #     "date_of_birth" => "1996-09-27T08:24:36.505Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/80.jpg"
  #   }
  # },
  # %{
  #   "email" => "svitozara.zabarniy@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2097",
  #       "address2" => "Geroyiv Holodnogo Yaru",
  #       "city" => "Hrestivka",
  #       "country" => "Ukraine",
  #       "home_phone" => "(067) V39-4423",
  #       "mobile" => "(066) E11-5129",
  #       "state" => "Avtonomna Respublika Krim"
  #     },
  #     "first_name" => "Svitozara",
  #     "last_name" => "Zabarniy",
  #     "date_of_birth" => "1956-10-06T05:25:18.541Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/57.jpg"
  #   }
  # },
  # %{
  #   "email" => "todd.morrison@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8380",
  #       "address2" => "The Avenue",
  #       "city" => "Tramore",
  #       "country" => "Ireland",
  #       "home_phone" => "041-222-3847",
  #       "mobile" => "081-638-2249",
  #       "state" => "Galway City"
  #     },
  #     "first_name" => "Todd",
  #     "last_name" => "Morrison",
  #     "date_of_birth" => "1948-04-20T04:30:53.937Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/54.jpg"
  #   }
  # },
  # %{
  #   "email" => "jen.carroll@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6247",
  #       "address2" => "North Road",
  #       "city" => "Sligo",
  #       "country" => "Ireland",
  #       "home_phone" => "071-357-0808",
  #       "mobile" => "081-044-3129",
  #       "state" => "Sligo"
  #     },
  #     "first_name" => "Jen",
  #     "last_name" => "Carroll",
  #     "date_of_birth" => "1945-05-30T13:14:54.207Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/83.jpg"
  #   }
  # },
  # %{
  #   "email" => "joseluis.rendon@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3939",
  #       "address2" => "Calzada Norte Madrid",
  #       "city" => "Santa Mónica",
  #       "country" => "Mexico",
  #       "home_phone" => "(688) 624 9619",
  #       "mobile" => "(605) 307 8049",
  #       "state" => "Aguascalientes"
  #     },
  #     "first_name" => "José Luis",
  #     "last_name" => "Rendón",
  #     "date_of_birth" => "1992-08-03T02:55:26.378Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/15.jpg"
  #   }
  # },
  # %{
  #   "email" => "daniel.camarillo@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4946",
  #       "address2" => "Peatonal Coahuila de Zaragoza",
  #       "city" => "Aguaruto",
  #       "country" => "Mexico",
  #       "home_phone" => "(685) 655 7471",
  #       "mobile" => "(626) 646 0080",
  #       "state" => "Sonora"
  #     },
  #     "first_name" => "Daniel",
  #     "last_name" => "Camarillo",
  #     "date_of_birth" => "1992-11-14T04:55:29.299Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/18.jpg"
  #   }
  # },
  # %{
  #   "email" => "elling.gjessing@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "576",
  #       "address2" => "Ombergveien",
  #       "city" => "Brandsøy",
  #       "country" => "Norway",
  #       "home_phone" => "38149926",
  #       "mobile" => "45224645",
  #       "state" => "Vestfold"
  #     },
  #     "first_name" => "Elling",
  #     "last_name" => "Gjessing",
  #     "date_of_birth" => "1990-08-15T19:24:50.509Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/15.jpg"
  #   }
  # },
  # %{
  #   "email" => "marshall.baker@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1335",
  #       "address2" => "Pockrus Page Rd",
  #       "city" => "Lincoln",
  #       "country" => "United States",
  #       "home_phone" => "(873) 471-4747",
  #       "mobile" => "(604) 376-5753",
  #       "state" => "Montana"
  #     },
  #     "first_name" => "Marshall",
  #     "last_name" => "Baker",
  #     "date_of_birth" => "1979-12-27T09:36:28.726Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/10.jpg"
  #   }
  # },
  # %{
  #   "email" => "medina.fernandez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7634",
  #       "address2" => "Place du 8 Novembre 1942",
  #       "city" => "Vechigen",
  #       "country" => "Switzerland",
  #       "home_phone" => "075 234 83 55",
  #       "mobile" => "077 335 34 42",
  #       "state" => "Obwalden"
  #     },
  #     "first_name" => "Medina",
  #     "last_name" => "Fernandez",
  #     "date_of_birth" => "1990-04-14T19:17:47.090Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/9.jpg"
  #   }
  # },
  # %{
  #   "email" => "gregor.sailer@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1892",
  #       "address2" => "Brunnenstraße",
  #       "city" => "Radebeul",
  #       "country" => "Germany",
  #       "home_phone" => "0472-4329053",
  #       "mobile" => "0172-8560835",
  #       "state" => "Hamburg"
  #     },
  #     "first_name" => "Gregor",
  #     "last_name" => "Sailer",
  #     "date_of_birth" => "1959-03-05T18:54:28.286Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/38.jpg"
  #   }
  # },
  # %{
  #   "email" => "coskun.koyluoglu@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1327",
  #       "address2" => "Istiklal Cd",
  #       "city" => "Kahramanmaraş",
  #       "country" => "Turkey",
  #       "home_phone" => "(713)-119-5742",
  #       "mobile" => "(683)-025-4290",
  #       "state" => "Afyonkarahisar"
  #     },
  #     "first_name" => "Coşkun",
  #     "last_name" => "Köylüoğlu",
  #     "date_of_birth" => "1957-06-20T11:38:49.409Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/24.jpg"
  #   }
  # },
  # %{
  #   "email" => "chloe.brown@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4577",
  #       "address2" => "Grand Ave",
  #       "city" => "Stratford",
  #       "country" => "Canada",
  #       "home_phone" => "G25 Y78-4249",
  #       "mobile" => "U15 M13-6375",
  #       "state" => "Yukon"
  #     },
  #     "first_name" => "Chloe",
  #     "last_name" => "Brown",
  #     "date_of_birth" => "1963-07-03T01:58:29.559Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/93.jpg"
  #   }
  # },
  # %{
  #   "email" => "joshua.moore@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9910",
  #       "address2" => "East Tamaki Road",
  #       "city" => "Whanganui",
  #       "country" => "New Zealand",
  #       "home_phone" => "(012)-462-0076",
  #       "mobile" => "(800)-779-6676",
  #       "state" => "Marlborough"
  #     },
  #     "first_name" => "Joshua",
  #     "last_name" => "Moore",
  #     "date_of_birth" => "1972-01-03T10:45:12.769Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/5.jpg"
  #   }
  # },
  # %{
  #   "email" => "kubra.yildirim@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3090",
  #       "address2" => "Fatih Sultan Mehmet Cd",
  #       "city" => "Trabzon",
  #       "country" => "Turkey",
  #       "home_phone" => "(820)-459-0259",
  #       "mobile" => "(637)-561-9561",
  #       "state" => "Rize"
  #     },
  #     "first_name" => "Kübra",
  #     "last_name" => "Yıldırım",
  #     "date_of_birth" => "1959-03-03T07:53:14.818Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/94.jpg"
  #   }
  # },
  # %{
  #   "email" => "orlando.vazquez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1804",
  #       "address2" => "Eje vial Limón",
  #       "city" => "Tequesquitengo",
  #       "country" => "Mexico",
  #       "home_phone" => "(634) 987 0353",
  #       "mobile" => "(691) 857 2240",
  #       "state" => "Quintana Roo"
  #     },
  #     "first_name" => "Orlando",
  #     "last_name" => "Vázquez",
  #     "date_of_birth" => "1998-12-27T16:23:17.700Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
  #   }
  # },
  # %{
  #   "email" => "stephanie.nguyen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1409",
  #       "address2" => "Ormond Quay",
  #       "city" => "Rush",
  #       "country" => "Ireland",
  #       "home_phone" => "051-865-7311",
  #       "mobile" => "081-823-5593",
  #       "state" => "Galway"
  #     },
  #     "first_name" => "Stephanie",
  #     "last_name" => "Nguyen",
  #     "date_of_birth" => "1962-04-02T21:05:17.730Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/57.jpg"
  #   }
  # },
  # %{
  #   "email" => "liam.park@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1838",
  #       "address2" => "Charles St",
  #       "city" => "Jasper",
  #       "country" => "Canada",
  #       "home_phone" => "Z71 A88-0976",
  #       "mobile" => "D39 Q88-7937",
  #       "state" => "Prince Edward Island"
  #     },
  #     "first_name" => "Liam",
  #     "last_name" => "Park",
  #     "date_of_birth" => "1990-04-01T21:47:48.307Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/37.jpg"
  #   }
  # },
  # %{
  #   "email" => "kim.henry@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4971",
  #       "address2" => "Park Lane",
  #       "city" => "Dundalk",
  #       "country" => "Ireland",
  #       "home_phone" => "031-143-2783",
  #       "mobile" => "081-382-2347",
  #       "state" => "Kilkenny"
  #     },
  #     "first_name" => "Kim",
  #     "last_name" => "Henry",
  #     "date_of_birth" => "1997-10-27T05:45:24.165Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/61.jpg"
  #   }
  # },
  # %{
  #   "email" => "dylan.wells@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4249",
  #       "address2" => "Woodland St",
  #       "city" => "Tamworth",
  #       "country" => "Australia",
  #       "home_phone" => "06-2947-6109",
  #       "mobile" => "0476-408-141",
  #       "state" => "Tasmania"
  #     },
  #     "first_name" => "Dylan",
  #     "last_name" => "Wells",
  #     "date_of_birth" => "1967-03-04T23:06:15.463Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
  #   }
  # },
  # %{
  #   "email" => "kasper.kristensen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5270",
  #       "address2" => "Bøgelunden",
  #       "city" => "Aarhus",
  #       "country" => "Denmark",
  #       "home_phone" => "13610961",
  #       "mobile" => "84662931",
  #       "state" => "Sjælland"
  #     },
  #     "first_name" => "Kasper",
  #     "last_name" => "Kristensen",
  #     "date_of_birth" => "1947-12-09T02:11:10.855Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/20.jpg"
  #   }
  # },
  # %{
  #   "email" => "sanja.loncarevic@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2475",
  #       "address2" => "Porodice Simonović",
  #       "city" => "Bogatić",
  #       "country" => "Serbia",
  #       "home_phone" => "024-8613-110",
  #       "mobile" => "063-6052-919",
  #       "state" => "Toplica"
  #     },
  #     "first_name" => "Sanja",
  #     "last_name" => "Lončarević",
  #     "date_of_birth" => "1971-01-11T23:01:25.035Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/3.jpg"
  #   }
  # },
  # %{
  #   "email" => "alexander.thomsen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5971",
  #       "address2" => "Rolighedsvej",
  #       "city" => "Aaborg Øst",
  #       "country" => "Denmark",
  #       "home_phone" => "55910809",
  #       "mobile" => "86323813",
  #       "state" => "Sjælland"
  #     },
  #     "first_name" => "Alexander",
  #     "last_name" => "Thomsen",
  #     "date_of_birth" => "1971-03-27T15:21:13.696Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/25.jpg"
  #   }
  # },
  # %{
  #   "email" => "bushra.rolfsnes@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9862",
  #       "address2" => "Svingen terrasse",
  #       "city" => "Eidfjord",
  #       "country" => "Norway",
  #       "home_phone" => "61026649",
  #       "mobile" => "49324682",
  #       "state" => "Oppland"
  #     },
  #     "first_name" => "Bushra",
  #     "last_name" => "Rolfsnes",
  #     "date_of_birth" => "1959-03-09T09:38:53.858Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/89.jpg"
  #   }
  # },
  # %{
  #   "email" => "isabel.clarke@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6424",
  #       "address2" => "Evans Street",
  #       "city" => "Masterton",
  #       "country" => "New Zealand",
  #       "home_phone" => "(123)-897-6209",
  #       "mobile" => "(036)-302-1987",
  #       "state" => "Gisborne"
  #     },
  #     "first_name" => "Isabel",
  #     "last_name" => "Clarke",
  #     "date_of_birth" => "1973-10-06T14:08:55.344Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/54.jpg"
  #   }
  # },
  # %{
  #   "email" => "philippe.jones@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1461",
  #       "address2" => "Simcoe St",
  #       "city" => "Southampton",
  #       "country" => "Canada",
  #       "home_phone" => "N96 D48-4531",
  #       "mobile" => "V48 F57-0022",
  #       "state" => "Northwest Territories"
  #     },
  #     "first_name" => "Philippe",
  #     "last_name" => "Jones",
  #     "date_of_birth" => "1994-10-08T16:45:40.044Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/93.jpg"
  #   }
  # },
  # %{
  #   "email" => "lena.herwig@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4909",
  #       "address2" => "Römerstraße",
  #       "city" => "Coswig",
  #       "country" => "Germany",
  #       "home_phone" => "0144-2690471",
  #       "mobile" => "0171-1918985",
  #       "state" => "Sachsen-Anhalt"
  #     },
  #     "first_name" => "Lena",
  #     "last_name" => "Herwig",
  #     "date_of_birth" => "1954-11-30T19:09:49.860Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/24.jpg"
  #   }
  # },
  # %{
  #   "email" => "emilie.walker@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "39",
  #       "address2" => "Oak St",
  #       "city" => "Dorchester",
  #       "country" => "Canada",
  #       "home_phone" => "P61 C53-0873",
  #       "mobile" => "J06 C60-1815",
  #       "state" => "Saskatchewan"
  #     },
  #     "first_name" => "Emilie",
  #     "last_name" => "Walker",
  #     "date_of_birth" => "1964-07-22T20:34:45.852Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/78.jpg"
  #   }
  # },
  # %{
  #   "email" => "kadir.eksioglu@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3523",
  #       "address2" => "Istiklal Cd",
  #       "city" => "Adıyaman",
  #       "country" => "Turkey",
  #       "home_phone" => "(825)-952-1904",
  #       "mobile" => "(089)-915-5406",
  #       "state" => "Sinop"
  #     },
  #     "first_name" => "Kadir",
  #     "last_name" => "Ekşioğlu",
  #     "date_of_birth" => "1996-06-27T10:14:42.289Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/40.jpg"
  #   }
  # },
  # %{
  #   "email" => "davut.atan@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7671",
  #       "address2" => "Tunalı Hilmi Cd",
  #       "city" => "Zonguldak",
  #       "country" => "Turkey",
  #       "home_phone" => "(159)-420-4843",
  #       "mobile" => "(975)-811-7486",
  #       "state" => "Osmaniye"
  #     },
  #     "first_name" => "Davut",
  #     "last_name" => "Atan",
  #     "date_of_birth" => "1946-11-20T20:56:43.931Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/27.jpg"
  #   }
  # },
  # %{
  #   "email" => "milena.peric@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4647",
  #       "address2" => "Kolibinska",
  #       "city" => "Brus",
  #       "country" => "Serbia",
  #       "home_phone" => "034-4645-346",
  #       "mobile" => "069-2936-472",
  #       "state" => "Jablanica"
  #     },
  #     "first_name" => "Milena",
  #     "last_name" => "Perić",
  #     "date_of_birth" => "1957-11-10T18:44:42.046Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/87.jpg"
  #   }
  # },
  # %{
  #   "email" => "jake.simmons@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7633",
  #       "address2" => "Rochestown Road",
  #       "city" => "Newbridge",
  #       "country" => "Ireland",
  #       "home_phone" => "011-640-7793",
  #       "mobile" => "081-735-5112",
  #       "state" => "Kildare"
  #     },
  #     "first_name" => "Jake",
  #     "last_name" => "Simmons",
  #     "date_of_birth" => "1990-09-14T11:06:04.715Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/87.jpg"
  #   }
  # },
  # %{
  #   "email" => "rayan.norberg@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9614",
  #       "address2" => "Bergslia",
  #       "city" => "Hovin",
  #       "country" => "Norway",
  #       "home_phone" => "80245941",
  #       "mobile" => "44635116",
  #       "state" => "Nordland"
  #     },
  #     "first_name" => "Rayan",
  #     "last_name" => "Norberg",
  #     "date_of_birth" => "1989-09-06T16:33:49.207Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/40.jpg"
  #   }
  # },
  # %{
  #   "email" => "dina.shafranskiy@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2618",
  #       "address2" => "Generala Matikina",
  #       "city" => "Zalizne",
  #       "country" => "Ukraine",
  #       "home_phone" => "(097) U53-9351",
  #       "mobile" => "(066) C47-3332",
  #       "state" => "Kirovogradska"
  #     },
  #     "first_name" => "Dina",
  #     "last_name" => "Shafranskiy",
  #     "date_of_birth" => "1979-04-23T20:40:52.819Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/30.jpg"
  #   }
  # },
  # %{
  #   "email" => "gorun.minyaylo@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9156",
  #       "address2" => "Shulginih",
  #       "city" => "Stariy Krim",
  #       "country" => "Ukraine",
  #       "home_phone" => "(098) A46-3079",
  #       "mobile" => "(099) F12-5835",
  #       "state" => "Kiyivska"
  #     },
  #     "first_name" => "Gorun",
  #     "last_name" => "Minyaylo",
  #     "date_of_birth" => "1952-06-28T14:47:13.334Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/53.jpg"
  #   }
  # },
  # %{
  #   "email" => "nellie.jennings@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1241",
  #       "address2" => "Lone Wolf Trail",
  #       "city" => "Winston–Salem",
  #       "country" => "United States",
  #       "home_phone" => "(330) 776-1380",
  #       "mobile" => "(592) 793-1317",
  #       "state" => "Virginia"
  #     },
  #     "first_name" => "Nellie",
  #     "last_name" => "Jennings",
  #     "date_of_birth" => "1987-03-10T00:47:18.814Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/47.jpg"
  #   }
  # },
  # %{
  #   "email" => "florence.gauthier@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7962",
  #       "address2" => "Grand Ave",
  #       "city" => "Cumberland",
  #       "country" => "Canada",
  #       "home_phone" => "P64 Q77-1966",
  #       "mobile" => "F79 Q14-7192",
  #       "state" => "Prince Edward Island"
  #     },
  #     "first_name" => "Florence",
  #     "last_name" => "Gauthier",
  #     "date_of_birth" => "1992-09-15T13:09:18.180Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/51.jpg"
  #   }
  # },
  # %{
  #   "email" => "mille.jorgensen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "379",
  #       "address2" => "Ågade",
  #       "city" => "Ølstykke",
  #       "country" => "Denmark",
  #       "home_phone" => "66880724",
  #       "mobile" => "39414834",
  #       "state" => "Midtjylland"
  #     },
  #     "first_name" => "Mille",
  #     "last_name" => "Jørgensen",
  #     "date_of_birth" => "1990-08-03T20:39:34.896Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/82.jpg"
  #   }
  # },
  # %{
  #   "email" => "alexander.patel@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2320",
  #       "address2" => "20th Ave",
  #       "city" => "Grand Falls",
  #       "country" => "Canada",
  #       "home_phone" => "Z14 S64-8050",
  #       "mobile" => "Y84 K64-6519",
  #       "state" => "Prince Edward Island"
  #     },
  #     "first_name" => "Alexander",
  #     "last_name" => "Patel",
  #     "date_of_birth" => "1976-03-04T14:33:15.167Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/53.jpg"
  #   }
  # },
  # %{
  #   "email" => "nazario.trujillo@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9987",
  #       "address2" => "Calle Armenia",
  #       "city" => "Coyotepec",
  #       "country" => "Mexico",
  #       "home_phone" => "(652) 842 8656",
  #       "mobile" => "(697) 715 6477",
  #       "state" => "Estado de Mexico"
  #     },
  #     "first_name" => "Nazario",
  #     "last_name" => "Trujillo",
  #     "date_of_birth" => "1967-01-16T05:43:37.602Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/62.jpg"
  #   }
  # },
  # %{
  #   "email" => "alisia.moraes@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6515",
  #       "address2" => "Rua Um",
  #       "city" => "Araras",
  #       "country" => "Brazil",
  #       "home_phone" => "(29) 2799-8184",
  #       "mobile" => "(68) 1428-2474",
  #       "state" => "Goiás"
  #     },
  #     "first_name" => "Alísia",
  #     "last_name" => "Moraes",
  #     "date_of_birth" => "1947-12-16T12:11:31.225Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/11.jpg"
  #   }
  # },
  # %{
  #   "email" => "myld.khrymy@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2966",
  #       "address2" => "شهید ثانی",
  #       "city" => "نیشابور",
  #       "country" => "Iran",
  #       "home_phone" => "005-95450445",
  #       "mobile" => "0949-370-7859",
  #       "state" => "چهارمحال و بختیاری"
  #     },
  #     "first_name" => "میلاد",
  #     "last_name" => "کریمی",
  #     "date_of_birth" => "1987-08-31T16:05:23.065Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/15.jpg"
  #   }
  # },
  # %{
  #   "email" => "ayush.shah@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2832",
  #       "address2" => "Commercial St",
  #       "city" => "Madanapalle",
  #       "country" => "India",
  #       "home_phone" => "9799657679",
  #       "mobile" => "8848564338",
  #       "state" => "Manipur"
  #     },
  #     "first_name" => "Ayush",
  #     "last_name" => "Shah",
  #     "date_of_birth" => "1975-06-21T11:52:02.181Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/43.jpg"
  #   }
  # },
  # %{
  #   "email" => "clark.veldstra@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3469",
  #       "address2" => "Kennedylaan",
  #       "city" => "Breukeleveen",
  #       "country" => "Netherlands",
  #       "home_phone" => "(0887) 615881",
  #       "mobile" => "(06) 48362517",
  #       "state" => "Flevoland"
  #     },
  #     "first_name" => "Clark",
  #     "last_name" => "Veldstra",
  #     "date_of_birth" => "1945-10-07T14:59:29.919Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/42.jpg"
  #   }
  # },
  # %{
  #   "email" => "filipa.duarte@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5725",
  #       "address2" => "Rua Maranhão ",
  #       "city" => "Vespasiano",
  #       "country" => "Brazil",
  #       "home_phone" => "(81) 1834-5803",
  #       "mobile" => "(17) 9452-9252",
  #       "state" => "Goiás"
  #     },
  #     "first_name" => "Filipa",
  #     "last_name" => "Duarte",
  #     "date_of_birth" => "1952-05-14T21:28:42.932Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/76.jpg"
  #   }
  # },
  # %{
  #   "email" => "willy.roy@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "6661",
  #       "address2" => "Rue du Moulin",
  #       "city" => "Cademario",
  #       "country" => "Switzerland",
  #       "home_phone" => "075 496 10 42",
  #       "mobile" => "075 322 96 52",
  #       "state" => "Vaud"
  #     },
  #     "first_name" => "Willy",
  #     "last_name" => "Roy",
  #     "date_of_birth" => "1969-09-16T11:39:52.290Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/28.jpg"
  #   }
  # },
  # %{
  #   "email" => "shelly.pierce@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8435",
  #       "address2" => "Green Rd",
  #       "city" => "Seattle",
  #       "country" => "United States",
  #       "home_phone" => "(372) 380-8205",
  #       "mobile" => "(653) 894-3656",
  #       "state" => "Rhode Island"
  #     },
  #     "first_name" => "Shelly",
  #     "last_name" => "Pierce",
  #     "date_of_birth" => "1974-06-17T16:28:29.563Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/27.jpg"
  #   }
  # },
  # %{
  #   "email" => "carlos.gamez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "984",
  #       "address2" => "Peatonal Garza",
  #       "city" => "Punta del Agua",
  #       "country" => "Mexico",
  #       "home_phone" => "(665) 293 0690",
  #       "mobile" => "(660) 121 8512",
  #       "state" => "Baja California Sur"
  #     },
  #     "first_name" => "Carlos",
  #     "last_name" => "Gamez",
  #     "date_of_birth" => "1994-12-04T09:06:00.235Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/16.jpg"
  #   }
  # },
  # %{
  #   "email" => "myrhsyn.glshn@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2324",
  #       "address2" => "کوی نصر",
  #       "city" => "گلستان",
  #       "country" => "Iran",
  #       "home_phone" => "099-76940326",
  #       "mobile" => "0975-646-4645",
  #       "state" => "آذربایجان غربی"
  #     },
  #     "first_name" => "اميرحسين",
  #     "last_name" => "گلشن",
  #     "date_of_birth" => "1984-03-07T19:49:55.726Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/93.jpg"
  #   }
  # },
  # %{
  #   "email" => "khymy.sdr@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7331",
  #       "address2" => "شهید صابونچی",
  #       "city" => "خرم‌آباد",
  #       "country" => "Iran",
  #       "home_phone" => "012-43761501",
  #       "mobile" => "0981-396-5693",
  #       "state" => "البرز"
  #     },
  #     "first_name" => "کیمیا",
  #     "last_name" => "صدر",
  #     "date_of_birth" => "1968-10-13T18:41:31.135Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/45.jpg"
  #   }
  # },
  # %{
  #   "email" => "ege.daglaroglu@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1693",
  #       "address2" => "Kushimoto Sk",
  #       "city" => "Edirne",
  #       "country" => "Turkey",
  #       "home_phone" => "(102)-350-2027",
  #       "mobile" => "(400)-833-6005",
  #       "state" => "Giresun"
  #     },
  #     "first_name" => "Ege",
  #     "last_name" => "Dağlaroğlu",
  #     "date_of_birth" => "1986-09-24T12:35:59.228Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/91.jpg"
  #   }
  # },
  # %{
  #   "email" => "joop.colak@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2415",
  #       "address2" => "Groene Dijk",
  #       "city" => "Luddeweer",
  #       "country" => "Netherlands",
  #       "home_phone" => "(096) 4773290",
  #       "mobile" => "(06) 31768135",
  #       "state" => "Noord-Brabant"
  #     },
  #     "first_name" => "Joop",
  #     "last_name" => "Çolak",
  #     "date_of_birth" => "1992-08-03T11:27:42.436Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/10.jpg"
  #   }
  # },
  # %{
  #   "email" => "daisy.lynch@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4432",
  #       "address2" => "Westheimer Rd",
  #       "city" => "Busselton",
  #       "country" => "Australia",
  #       "home_phone" => "07-6171-2812",
  #       "mobile" => "0470-854-162",
  #       "state" => "Victoria"
  #     },
  #     "first_name" => "Daisy",
  #     "last_name" => "Lynch",
  #     "date_of_birth" => "1960-05-10T13:21:13.170Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/58.jpg"
  #   }
  # },
  # %{
  #   "email" => "oscar.gallego@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3435",
  #       "address2" => "Avenida de Burgos",
  #       "city" => "Valladolid",
  #       "country" => "Spain",
  #       "home_phone" => "935-833-220",
  #       "mobile" => "681-843-080",
  #       "state" => "La Rioja"
  #     },
  #     "first_name" => "Oscar",
  #     "last_name" => "Gallego",
  #     "date_of_birth" => "1955-06-12T07:47:08.096Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/33.jpg"
  #   }
  # },
  # %{
  #   "email" => "vicky.gutierrez@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "109",
  #       "address2" => "Fairview Road",
  #       "city" => "Salisbury",
  #       "country" => "United Kingdom",
  #       "home_phone" => "016974 21706",
  #       "mobile" => "07538 158430",
  #       "state" => "County Antrim"
  #     },
  #     "first_name" => "Vicky",
  #     "last_name" => "Gutierrez",
  #     "date_of_birth" => "1950-08-31T07:43:09.972Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/11.jpg"
  #   }
  # },
  # %{
  #   "email" => "ondino.silva@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "720",
  #       "address2" => "Rua Dois",
  #       "city" => "Franco da Rocha",
  #       "country" => "Brazil",
  #       "home_phone" => "(70) 8575-4888",
  #       "mobile" => "(25) 0896-0501",
  #       "state" => "Piauí"
  #     },
  #     "first_name" => "Ondino",
  #     "last_name" => "Silva",
  #     "date_of_birth" => "1959-01-16T07:35:11.075Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/67.jpg"
  #   }
  # },
  # %{
  #   "email" => "abhijith.acharya@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8422",
  #       "address2" => "Marine Drive",
  #       "city" => "Nagercoil",
  #       "country" => "India",
  #       "home_phone" => "7900035446",
  #       "mobile" => "7766672170",
  #       "state" => "Jharkhand"
  #     },
  #     "first_name" => "Abhijith",
  #     "last_name" => "Acharya",
  #     "date_of_birth" => "1995-04-06T04:27:54.983Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/98.jpg"
  #   }
  # },
  # %{
  #   "email" => "dora.vujicic@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "7606",
  #       "address2" => "Zlatnih Rukoveti",
  #       "city" => "Belgrade",
  #       "country" => "Serbia",
  #       "home_phone" => "015-5243-655",
  #       "mobile" => "060-8610-978",
  #       "state" => "Braničevo"
  #     },
  #     "first_name" => "Dora",
  #     "last_name" => "Vujičić",
  #     "date_of_birth" => "1951-04-20T18:34:57.917Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/33.jpg"
  #   }
  # },
  # %{
  #   "email" => "kristin.phillips@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3835",
  #       "address2" => "Church Road",
  #       "city" => "City of London",
  #       "country" => "United Kingdom",
  #       "home_phone" => "015396 76271",
  #       "mobile" => "07866 159169",
  #       "state" => "Norfolk"
  #     },
  #     "first_name" => "Kristin",
  #     "last_name" => "Phillips",
  #     "date_of_birth" => "1988-01-17T07:44:11.795Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/30.jpg"
  #   }
  # },
  # %{
  #   "email" => "elias.canales@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3356",
  #       "address2" => "Continuación Grecia",
  #       "city" => "San Marcos Nepantla",
  #       "country" => "Mexico",
  #       "home_phone" => "(665) 870 7215",
  #       "mobile" => "(664) 102 8185",
  #       "state" => "Guanajuato"
  #     },
  #     "first_name" => "Elias",
  #     "last_name" => "Canales",
  #     "date_of_birth" => "1959-10-29T04:11:43.088Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/82.jpg"
  #   }
  # },
  # %{
  #   "email" => "margie.hall@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9222",
  #       "address2" => "E Little York Rd",
  #       "city" => "Melbourne",
  #       "country" => "Australia",
  #       "home_phone" => "07-7852-9355",
  #       "mobile" => "0428-082-261",
  #       "state" => "Australian Capital Territory"
  #     },
  #     "first_name" => "Margie",
  #     "last_name" => "Hall",
  #     "date_of_birth" => "2000-02-17T08:21:01.256Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/65.jpg"
  #   }
  # },
  # %{
  #   "email" => "samantha.wang@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "4482",
  #       "address2" => "Glenfield Road",
  #       "city" => "Tauranga",
  #       "country" => "New Zealand",
  #       "home_phone" => "(298)-226-2623",
  #       "mobile" => "(683)-764-2321",
  #       "state" => "Nelson"
  #     },
  #     "first_name" => "Samantha",
  #     "last_name" => "Wang",
  #     "date_of_birth" => "1982-11-26T07:49:03.061Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/92.jpg"
  #   }
  # },
  # %{
  #   "email" => "margarethe.trommer@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2129",
  #       "address2" => "Goethestraße",
  #       "city" => "Münchenbernsdorf",
  #       "country" => "Germany",
  #       "home_phone" => "0172-5092440",
  #       "mobile" => "0179-5938827",
  #       "state" => "Bayern"
  #     },
  #     "first_name" => "Margarethe",
  #     "last_name" => "Trommer",
  #     "date_of_birth" => "1991-09-25T02:58:19.334Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/42.jpg"
  #   }
  # },
  # %{
  #   "email" => "atharv.singh@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9257",
  #       "address2" => "Gandhi Maidan Marg",
  #       "city" => "Jabalpur",
  #       "country" => "India",
  #       "home_phone" => "7820421059",
  #       "mobile" => "9510595341",
  #       "state" => "Puducherry"
  #     },
  #     "first_name" => "Atharv",
  #     "last_name" => "Singh",
  #     "date_of_birth" => "1995-03-02T19:07:14.302Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/17.jpg"
  #   }
  # },
  # %{
  #   "email" => "alan.stotz@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "5069",
  #       "address2" => "Berliner Straße",
  #       "city" => "Freising",
  #       "country" => "Germany",
  #       "home_phone" => "0315-7022311",
  #       "mobile" => "0177-8563005",
  #       "state" => "Mecklenburg-Vorpommern"
  #     },
  #     "first_name" => "Alan",
  #     "last_name" => "Stotz",
  #     "date_of_birth" => "1950-03-07T05:01:44.877Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/92.jpg"
  #   }
  # },
  # %{
  #   "email" => "jeff.silva@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "2638",
  #       "address2" => "Westheimer Rd",
  #       "city" => "Bundaberg",
  #       "country" => "Australia",
  #       "home_phone" => "02-5048-5480",
  #       "mobile" => "0456-099-212",
  #       "state" => "Australian Capital Territory"
  #     },
  #     "first_name" => "Jeff",
  #     "last_name" => "Silva",
  #     "date_of_birth" => "1967-03-21T08:04:14.826Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/48.jpg"
  #   }
  # },
  # %{
  #   "email" => "maral.vandiggelen@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "1263",
  #       "address2" => "Dijkhofstraat",
  #       "city" => "Eagum",
  #       "country" => "Netherlands",
  #       "home_phone" => "(028) 5268187",
  #       "mobile" => "(06) 37717277",
  #       "state" => "Utrecht"
  #     },
  #     "first_name" => "Maral",
  #     "last_name" => "Van Diggelen",
  #     "date_of_birth" => "1972-07-07T19:25:37.039Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/8.jpg"
  #   }
  # },
  # %{
  #   "email" => "ilona.saksa@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "3176",
  #       "address2" => "Aleksanterinkatu",
  #       "city" => "Harjavalta",
  #       "country" => "Finland",
  #       "home_phone" => "08-664-603",
  #       "mobile" => "046-827-98-66",
  #       "state" => "Päijät-Häme"
  #     },
  #     "first_name" => "Ilona",
  #     "last_name" => "Saksa",
  #     "date_of_birth" => "1952-05-26T06:20:43.659Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/80.jpg"
  #   }
  # },
  # %{
  #   "email" => "ofelia.bustos@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "8929",
  #       "address2" => "Avenida Hidalgo",
  #       "city" => "Hostotipaquillo",
  #       "country" => "Mexico",
  #       "home_phone" => "(654) 446 0638",
  #       "mobile" => "(673) 959 5249",
  #       "state" => "Tlaxcala"
  #     },
  #     "first_name" => "Ofelia",
  #     "last_name" => "Bustos",
  #     "date_of_birth" => "1950-11-23T05:03:24.830Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/20.jpg"
  #   }
  # },
  # %{
  #   "email" => "elya.lecomte@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9558",
  #       "address2" => "Rue Dugas-Montbel",
  #       "city" => "Orléans",
  #       "country" => "France",
  #       "home_phone" => "04-78-50-25-65",
  #       "mobile" => "06-12-34-69-30",
  #       "state" => "Bas-Rhin"
  #     },
  #     "first_name" => "Elya",
  #     "last_name" => "Lecomte",
  #     "date_of_birth" => "1976-10-09T19:30:07.810Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/78.jpg"
  #   }
  # },
  # %{
  #   "email" => "colin.chevalier@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "940",
  #       "address2" => "Place du 8 Novembre 1942",
  #       "city" => "Hirschthal",
  #       "country" => "Switzerland",
  #       "home_phone" => "076 696 07 45",
  #       "mobile" => "076 019 90 69",
  #       "state" => "Nidwalden"
  #     },
  #     "first_name" => "Colin",
  #     "last_name" => "Chevalier",
  #     "date_of_birth" => "1957-03-15T23:16:48.850Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/men/78.jpg"
  #   }
  # },
  # %{
  #   "email" => "fatma.gunday@example.com",
  #   "password"=> "passWORD1234@",
  #   "password_confirmation"=> "passWORD1234@",
  #   "organization_id" => initial_user.organization_id,
  #   "roles" => [Enum.random(Fleetms.Enums.user_roles())],
  #   "user_profile" => %{
  #     "contact" => %{
  #       "address" => "9975",
  #       "address2" => "Mevlana Cd",
  #       "city" => "Sivas",
  #       "country" => "Turkey",
  #       "home_phone" => "(127)-160-3065",
  #       "mobile" => "(601)-009-9063",
  #       "state" => "Malatya"
  #     },
  #     "first_name" => "Fatma",
  #     "last_name" => "Günday",
  #     "date_of_birth" => "1963-09-22T12:55:04.526Z",
  #     "profile_photo" => "https://randomuser.me/api/portraits/med/women/82.jpg"
  #   }
  # }
]

Enum.each(users, fn attrs ->
  Fleetms.Accounts.User
  |> Ash.Changeset.for_create(:create_organization_user, attrs)
  |> Ash.Changeset.set_context(%{private: %{ash_authentication?: true}})
  |> Ash.create!(actor: actor)
end)

nissan_models = [
  "PATROL",
  "CARAVAN",
  "CIVILIAN BUS",
  "PATHFINDER"
]

toyota_models = [
  "DYNA TRUCK",
  "FORTUNER",
  "HILUX",
  "LAND CRUISER",
  "TOYOACE"
]

mitsubishi_models = [
  "CANTER",
  "PAJERO",
  "ROSA",
  "TRITON"
]

daf_models = [
  "CF",
  "CF65",
  "LF"
]

man_models = [
  "TGM",
  "TGS"
]

scania_models = [
  "G SERIES",
  "P SERIES",
  "R SERIES"
]

vehicle_makes = [
  %{
    "name" => "Toyota"
  },
  %{
    "name" => "Nissan"
  },
  %{
    "name" => "Mitsubishi"
  },
  %{
    "name" => "Daf"
  },
  %{
    "name" => "Man"
  },
  %{
    "name" => "Scania"
  }
]

require Ash.Query

defmodule Repo.Seeds.VehicleMakes do
  def create_vehicle_make_and_models(attrs, models, tenant, actor) do
    make =
      Fleetms.Vehicles.VehicleMake
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: actor, tenant: tenant)

    Enum.each(models, fn model ->
      attrs = %{"name" => model, "vehicle_make" => %{"id" => make.id, "name" => make.name}}

      Fleetms.Vehicles.VehicleModel
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: actor, tenant: tenant)
    end)
  end
end

alias Repo.Seeds.VehicleMakes

tenant = initial_user.organization

Enum.each(vehicle_makes, fn attrs ->
  case attrs["name"] do
    "Toyota" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, toyota_models, tenant, actor)

    "Nissan" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, nissan_models, tenant, actor)

    "Mitsubishi" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, mitsubishi_models, tenant, actor)

    "Daf" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, daf_models, tenant, actor)

    "Man" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, man_models, tenant, actor)

    "Scania" ->
      VehicleMakes.create_vehicle_make_and_models(attrs, scania_models, tenant, actor)
  end
end)

vehicles = [
  %{
    license_plate: "291F069",
    mileage: 112_843,
    vehicle_model: %{name: "R SERIES", vehicle_make: %{name: "Scania"}},
    name: "R SERIES-26",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "70C51N7F870690660",
    year: 2015,
    status: :Active
  },
  %{
    license_plate: "F9B2CFF",
    mileage: 34227,
    vehicle_model: %{name: "P SERIES", vehicle_make: %{name: "Scania"}},
    name: "P SERIES-21",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "MF48HK0J720594663",
    year: 2007,
    status: :Active
  },
  %{
    license_plate: "85D0F8B",
    mileage: 142_842,
    vehicle_model: %{name: "G SERIES", vehicle_make: %{name: "Scania"}},
    name: "G SERIES-70",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "CZ18PT01NKCB40395",
    year: 2001,
    status: :Active
  },
  %{
    license_plate: "7ED8D47",
    mileage: 41268,
    vehicle_model: %{name: "TGS", vehicle_make: %{name: "Man"}},
    name: "TGS-72",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "5938RU50640398051",
    year: 2016,
    status: :Active
  },
  %{
    license_plate: "E203BBE",
    mileage: 187_984,
    vehicle_model: %{name: "TGM", vehicle_make: %{name: "Man"}},
    name: "TGM-84",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "613017JE3MVV47649",
    year: 2003,
    status: :Active
  },
  %{
    license_plate: "19FE219",
    mileage: 158_414,
    vehicle_model: %{name: "LF", vehicle_make: %{name: "Daf"}},
    name: "LF-58",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "0H2P3021UFE914050",
    year: 2006,
    status: :Active
  },
  %{
    license_plate: "0EDB1C0",
    mileage: 157_543,
    vehicle_model: %{name: "CF65", vehicle_make: %{name: "Daf"}},
    name: "CF65-91",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "R624KG58CTP094165",
    year: 2014,
    status: :Active
  },
  %{
    license_plate: "7799134",
    mileage: 105_598,
    vehicle_model: %{name: "CF", vehicle_make: %{name: "Daf"}},
    name: "CF-53",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "H8GHX13922CM34172",
    year: 2013,
    status: :Active
  },
  %{
    license_plate: "CF8FF7A",
    mileage: 50036,
    vehicle_model: %{name: "TRITON", vehicle_make: %{name: "Mitsubishi"}},
    name: "TRITON-14",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "9RHEF8928WD200277",
    year: 2008,
    status: :Active
  },
  %{
    license_plate: "1CC3CA3",
    mileage: 112_972,
    vehicle_model: %{name: "ROSA", vehicle_make: %{name: "Mitsubishi"}},
    name: "ROSA-20",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "BW0RYMR1XU0L80205",
    year: 2010,
    status: :Active
  },
  %{
    license_plate: "2CE5035",
    mileage: 96487,
    vehicle_model: %{name: "PAJERO", vehicle_make: %{name: "Mitsubishi"}},
    name: "PAJERO-91",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "6F9MZ3XXP00V90631",
    year: 2012,
    status: :Active
  },
  %{
    license_plate: "928D6B4",
    mileage: 113_087,
    vehicle_model: %{name: "CANTER", vehicle_make: %{name: "Mitsubishi"}},
    name: "CANTER-19",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "1900Z4B3KXC487293",
    year: 2013,
    status: :Active
  },
  %{
    license_plate: "CD958F8",
    mileage: 163_374,
    vehicle_model: %{name: "PATHFINDER", vehicle_make: %{name: "Nissan"}},
    name: "PATHFINDER-53",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "EAR7V344730N46771",
    year: 2015,
    status: :Active
  },
  %{
    license_plate: "7D6FF8D",
    mileage: 157_744,
    vehicle_model: %{name: "CIVILIAN BUS", vehicle_make: %{name: "Nissan"}},
    name: "CIVILIAN BUS-86",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "3E5FHGM99YJ792805",
    year: 2010,
    status: :Active
  },
  %{
    license_plate: "82DA497",
    mileage: 113_017,
    vehicle_model: %{name: "CARAVAN", vehicle_make: %{name: "Nissan"}},
    name: "CARAVAN-43",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "7A98UR17E7U163396",
    year: 2013,
    status: :Active
  },
  %{
    license_plate: "C022584",
    mileage: 150_215,
    vehicle_model: %{name: "PATROL", vehicle_make: %{name: "Nissan"}},
    name: "PATROL-67",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "W0D694G0G30891405",
    year: 2014,
    status: :Active
  },
  %{
    license_plate: "01378D0",
    mileage: 69852,
    vehicle_model: %{name: "TOYOACE", vehicle_make: %{name: "Toyota"}},
    name: "TOYOACE-93",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "F5P7Z3ATD80229626",
    year: 2010,
    status: :Active
  },
  %{
    license_plate: "C7FE66A",
    mileage: 42938,
    vehicle_model: %{name: "LAND CRUISER", vehicle_make: %{name: "Toyota"}},
    name: "LAND CRUISER-68",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "R00773AVX1SS05631",
    year: 2003,
    status: :Active
  },
  %{
    license_plate: "0E574F9",
    mileage: 187_962,
    vehicle_model: %{name: "HILUX", vehicle_make: %{name: "Toyota"}},
    name: "HILUX-6",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "012DT9WH080432006",
    year: 2008,
    status: :Active
  },
  %{
    license_plate: "9A13943",
    mileage: 194_249,
    vehicle_model: %{name: "FORTUNER", vehicle_make: %{name: "Toyota"}},
    name: "FORTUNER-53",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "AS1N900V48PB04386",
    year: 2011,
    status: :Active
  },
  %{
    license_plate: "F872F36",
    mileage: 149_341,
    vehicle_model: %{name: "DYNA TRUCK", vehicle_make: %{name: "Toyota"}},
    name: "DYNA TRUCK-99",
    type: "Truck",
    category: :"Commercial Trucks",
    vin: "D650B80579TP51016",
    year: 2006,
    status: :Active
  }
]

Enum.map(vehicles, fn attrs ->
  Fleetms.Vehicles.Vehicle
  |> Ash.Changeset.for_create(:seeding, attrs)
  |> Ash.create!(tenant: tenant, actor: actor)
end)

service_tasks =
  File.read!("#{:code.priv_dir(:fleetms)}/repo/seeds/service_tasks.json")
  |> Jason.decode!()

parts =
  File.read!("#{:code.priv_dir(:fleetms)}/repo/seeds/parts.json")
  |> Jason.decode!()

resource_names = Fleetms.Enums.resource_names()

Enum.each(resource_names, fn resource_name ->
  Fleetms.Common.Sequence
  |> Ash.Changeset.for_create(:create, %{})
  |> Ash.Changeset.force_change_attribute(:resource_name, resource_name)
  |> Ash.Changeset.force_change_attribute(:current_count, 1)
  |> Ash.create!(actor: actor, tenant: tenant)
end)

Enum.each(service_tasks, fn attrs ->
  Fleetms.Service.ServiceTask
  |> Ash.Changeset.for_create(:create, attrs)
  |> Ash.create!(actor: actor, tenant: tenant)
end)

Enum.each(parts, fn attrs ->
  Fleetms.Inventory.Part
  |> Ash.Changeset.for_create(:create, attrs)
  |> Ash.create!(actor: actor, tenant: tenant)
end)

inspection_form =
  Ash.create!(Fleetms.Inspection.InspectionForm, %{title: "Light Vehicles"},
    actor: actor,
    tenant: tenant
  )

inspection_form_inputs_params =
  File.read!("#{:code.priv_dir(:fleetms)}/repo/seeds/inspection_form_inputs.json")
  |> Jason.decode!()

Ash.update!(inspection_form, inspection_form_inputs_params, actor: actor, tenant: tenant)
