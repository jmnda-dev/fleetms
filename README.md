# Fleetms
### About
Fleetms is a Fleet Maintenance and Management software. Fleet in this context means Vehicles, that a company or person owns, and oversees the maintenance of such. This application is a free and open source and an alternative to other Fleet Management solutions out there. It is designed to streamline and optimize the operations of vehicle fleets, enhancing overall efficiency and improve resource allocation and reduce maintenance expenses. This software is a work in progress. I am are actively improving the code and adding new features.

### Purpose
This Fleet Management Software is created to solve the following problems:
- Efficient management of vehicle fleets
- Simplify the tracking and maintenance of vehicle inspections, maintenance and issues
- Tracking of fuel-related activities
- Real-time vehicle tracking (future implementation)

### Key Features
- Vehicles Module
  - Create, Read, Update, Delete (CRUD) operations for managing vehicle fleet.
  - Photos and Document storage and renewal reminders (e.g., Insurance).
  - Vehicle driver assignment for improved tracking and management.
  - General renewal reminders for various types of documents and activities.
    Customize reminders with types such as Insurance, Emissions Test, etc.
    Set intervals and receive notifications for upcoming renewals.

- Inspections Module
  - Management of inspection forms (similar to DVIR checklists) and submissions.

- Issues Module
  - Track and manage vehicle issues, keep upto date with maintenance requirements of your fleet.

- Service Groups and Service Reminder Module
  - Group vehicles by service needs for effective maintenance planning.
    Receive automated service reminders for timely maintenance.

- Work Orders Module
  - Record and manage all maintenance and repair work done on your vehicles.

- Parts and Inventory Module
  - Management of vehicle parts and inventory.

- Fuel Log Module(future integration with Fuel Card providers)
  - Tracking of fuel-related activities, including cost entries, providing insights into fuel efficiency and costs for better decision-making.

- Vehicle Tracking Module (Future Implementation)
  - Integration with third-party solutions for real-time vehicle tracking.


### NOTE
This project is a work in progress, and more details about the project will be added here. You can also take a look [HERE](https://github.com/users/jmnda-dev/projects/15/views/1)

## Technologies Used
- [**Ash Framework**](https://ash-hq.org/)
- [**Phoenix Framework**](https://hexdocs.pm/phoenix/overview.html)
- **Postgresql**
- [**Tailwind CSS**](https://tailwindcss.com/) and [**Flowbite**](https://flowbite.com/)

### Installation
You need to have PostgreSQL installed, then update the `config/dev.exs` file to use your database credentials.
Clone this repository
```bash
git clone https://github.com/jmnda-dev/fleetms.git
cd fleetms
```
You can run this project in Dev Containers locally or GitHub Codespaces.

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To reset database and seed sample data, run `mix seed`

If the sample data was seeded successfully, you can login with these credentials ***Email***: `demo_user@fleetms.com`, ***Password***: `passWORD1234@`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
