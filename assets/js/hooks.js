import darkModeToggleJs from "./dark-mode.js";
import SignaturePad from "signature_pad"
import PhotoSwipeLightbox from "photoswipe/lightbox";
import ApexCharts from 'apexcharts'
import { Drawer } from 'flowbite';
import moment from 'moment';
import sidebarInitJs from "./sidebar.js"
const humanizeDuration = require('humanize-duration');


Hooks = {};

Hooks.dispatchPhxLoadingStopEvent = {
  mounted() {
    this.handleEvent("initFlowbiteJS", _data => window.dispatchEvent(new Event("phx:page-loading-stop"), {
      bubbles: true,
      cancelable: true
    }));

  }
}

Hooks.initDarkModeToggle = {
  mounted() {
    darkModeToggleJs()
  }
}

Hooks.initSidebarJs = {
  mounted() {
    sidebarInitJs()
  },
}

Hooks.signaturePad = {
  mounted() {
    const signaturePad = new SignaturePad(this.el, {
      backgroundColor: '#FBD85D',
    })
    canvas = this.el;
    function resizeCanvas() {
      const ratio = Math.max(window.devicePixelRatio || 1, 1);
      canvas.width = canvas.offsetWidth * ratio;
      canvas.height = canvas.offsetHeight * ratio;
      canvas.getContext("2d").scale(ratio, ratio);
      signaturePad.clear(); // otherwise isEmpty() might return incorrect value
    }

    window.addEventListener("resize", resizeCanvas);
    resizeCanvas();

    signaturePad.addEventListener("endStroke", () => {
      inputId = canvas.getAttribute("data-input-target")
      inputEl = document.getElementById(inputId)
      inputEl.value = signaturePad.toDataURL()
    });
  }
}


Hooks.select2JS = {
  onChangeCallback(event, context) {

    // I use event.target.getAttribute('data-input-for') to match the appropriate case base on the input that changed.
    // That way the if for example the vehice model input has changed, the select input for the vehicle make won't be trigger, which would
    // result in pushing the event 'selected_vehicle_make' to the server even if the vehicle make didnt change.
    switch (event.target.getAttribute('data-input-for')) {
      case 'vehicle-make':
        value = event.params.data.text;
        context.pushEvent("selected_vehicle_make", { vehicle_make: value })
        break;

      default:
        break;
    }
  },
  mounted() {
    let context = this;

    let initializedEl = $(this.el).select2({
      placeholder: this.el.getAttribute('placeholder'),
      tags: true
    }).on('select2:select', (event) => this.onChangeCallback(event, context));

    this.handleEvent("set_new_options", function ({ targetEl, data }) {
      switch (targetEl) {
        case "current-input":
          $(context.el).select2({
            data: data,
            tags: true
          }).on('select2:select', (event) => context.onChangeCallback(event, context))
          break;

        case "other-input":
          let targetElementId = context.el.getAttribute('data-child-input-id')

          let targetEl = $(`#${targetElementId}`)

          // Clear existing options before setting new ones
          targetEl.empty()

          targetEl.select2({
            data: [{ id: '', text: '' }, ...data],
            tags: true
          }).on('select2:select', (event) => context.onChangeCallback(event, context))
          break;

        default:
          break;
      }
    })
  },
  destroyed() {
    $(this.el).select2('destroy')
  }
}

Hooks.photoswipeHook = {
  mounted() {
    const lightbox = new PhotoSwipeLightbox({
      gallery: this.el,
      children: 'a',
      pswpModule: () => import('photoswipe')
    })
    lightbox.init()
  }
}

Hooks.LocalTime = {
  mounted() {
    this.updated();
  },
  updated() {
    textContent = this.el.textContent.trim();
    excludeTime = this.el.getAttribute('data-exclude-time')

    if (textContent) {
      let dt = new Date(textContent);
      if (excludeTime) {
        this.el.textContent = dt.toDateString()
      } else {
        this.el.textContent = dt.toDateString() + " " + dt.toLocaleTimeString();
      }
    } else {
      this.el.innerHTML = "--";
    }
    this.el.classList.remove("invisible");
  }
}

Hooks.HumanizeText = {
  mounted() {
    this.el.querySelectorAll('[data-humanize]').forEach((element) => {
      text = element.textContent.trim();
      humanizedString = humanizeString(text)

      element.textContent = humanizedString;
    });
  },
  updated() {
    this.mounted()
  }
}

Hooks.FormatDateAndTime = {
  mounted() {
    this.updated();
  },
  updated() {
    textContent = this.el.textContent.trim();
    excludeTime = this.el.getAttribute('data-exclude-time')

    console.log(excludeTime)
    if (textContent) {
      let dt = new Date(textContent);
      if (excludeTime) {
        this.el.textContent = dt.toDateString()
      } else {
        this.el.textContent = dt.toDateString() + " " + dt.toLocaleTimeString();
      }
    } else {
      this.el.innerHTML = "--";
    }
    this.el.classList.remove("invisible");
  }
}

Hooks.vehiclesStats = {
  mounted() {
    element = this.el
    this.pushEvent("loadVehiclesStats", {})
    this.handleEvent("renderVehiclesStats", ({ series, labels }) => {

      const getChartOptions = () => {
        return {
          series: series,
          colors: ["#16BDCA", "#98baea", "#fdba8c"],
          chart: {
            height: 320,
            width: "100%",
            type: "donut",
          },
          stroke: {
            colors: ["white"],
            lineCap: "",
          },
          plotOptions: {
            pie: {
              donut: {
                labels: {
                  show: true,
                  total: {
                    showAlways: true,
                    show: true
                  }
                }
              }
            }
          },
          labels: labels,
          dataLabels: {
            enabled: true,
            style: {
              fontFamily: "Inter, sans-serif",
            },
          },
          legend: {
            position: "bottom",
            fontFamily: "Inter, sans-serif",
          },

          xaxis: {

            axisTicks: {
              show: false,
            },
            axisBorder: {
              show: false,
            },
          },
        }
      }
      var chart = new ApexCharts(document.getElementById("vehicles-stats-chart"), getChartOptions());
      chart.render();
    })
  }

}

Hooks.inspectionStats = {
  mounted() {
    element = this.el
    this.pushEvent("loadInspectionStats", {})
    this.handleEvent("renderInspectionStats", ({ series, colors }) => {
      if (window.inspectionStatsChart) {
        window.inspectionStatsChart.destroy()
      }
      const getChartOptions = () => {
        return {
          colors: colors,
          series: series,
          chart: {
            type: 'bar',
            height: '320px',
            fontFamily: 'Inter, sans-serif',
            foreColor: '#4B5563',
            toolbar: {
              show: false
            }
          },
          plotOptions: {
            bar: {
              columnWidth: '90%',
              borderRadius: 3
            }
          },
          tooltip: {
            shared: true,
            intersect: false,
            style: {
              fontSize: '14px',
              fontFamily: 'Inter, sans-serif'
            },
          },
          states: {
            hover: {
              filter: {
                type: 'darken',
                value: 1
              }
            }
          },
          stroke: {
            show: true,
            width: 5,
            colors: ['transparent']
          },
          grid: {
            show: false
          },
          dataLabels: {
            enabled: false
          },
          legend: {
            show: false
          },
          xaxis: {
            floating: false,
            labels: {
              show: true
            },
            axisBorder: {
              show: false
            },
            axisTicks: {
              show: false
            },
          },
          yaxis: {
            show: false
          },
          fill: {
            opacity: 1
          }
        }

      }

      const chart = new ApexCharts(document.getElementById("inspection-stats-chart"), getChartOptions());
      chart.render();

      window.inspectionStatsChart = chart
    })
  }
}

Hooks.issuesStats = {
  mounted() {
    this.pushEvent("loadIssuesStats", {})
  }

}

Hooks.TimePassed = {
  getTimePassed(datetimeString) {
    const currentTime = new Date();
    const pastTime = new Date(datetimeString);
    const timeDifference = currentTime - pastTime;

    // Convert milliseconds to seconds, minutes, hours, and days
    const seconds = Math.floor(timeDifference / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    // Return a human-readable string
    if (days > 0) {
      return `${days} day${days > 1 ? 's' : ''} ago`;
    } else if (hours > 0) {
      return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    } else if (minutes > 0) {
      return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    } else {
      return 'Just now';
    }
  },
  mounted() {
    const element = this.el

    if (element) {
      const datetimeString = element.textContent.trim();
      const timePassed = this.getTimePassed(datetimeString);
      element.innerHTML = timePassed
      element.classList.remove("invisible");
    }
  },
  updated() {
    this.mounted()
  }

}


Hooks.serviceRemindersStats = {
  mounted() {
    element = this.el
    this.pushEvent("loadServiceReminderStats", {})
    this.handleEvent("renderServiceRemindersStats", ({ series, labels }) => {

      const getChartOptions = () => {
        return {

          series: series,
          colors: ["#3F83F8", "#FACA15", "#F05252"],
          chart: {
            height: 320,
            width: "100%",
            type: "donut",
          },
          stroke: {
            colors: ["white"],
            lineCap: "",
          },
          plotOptions: {
            pie: {
              donut: {
                labels: {
                  show: true,
                  total: {
                    showAlways: true,
                    show: true
                  }
                }
              }
            }
          },
          labels: labels,
          dataLabels: {
            enabled: true,
            style: {
              fontFamily: "Inter, sans-serif",
            },
          },
          legend: {
            position: "bottom",
            fontFamily: "Inter, sans-serif",
          },

          xaxis: {

            axisTicks: {
              show: false,
            },
            axisBorder: {
              show: false,
            },
          },
        }
      }
      var chart = new ApexCharts(document.getElementById("service-reminders-stats-chart"), getChartOptions());
      chart.render();
    })
  }

}

Hooks.fuelStats = {
  mounted() {
    this.pushEvent("loadFuelStats", {})
    this.handleEvent("renderFuelStats", ({ series, categories, horizontal }) => {
      if (window.fuelStatsChart) {
        window.fuelStatsChart.destroy()
      }
      const options = {
        series: series,
        chart: {
          type: 'bar',
          height: horizontal && '2044px' || '620px',
          width: '100%',
          stacked: true,
        },
        stroke: {
          width: 1,
          colors: ['#fff']
        },
        dataLabels: {
          formatter: (val) => {
            if (val >= 1000) {
              return val / 1000 + 'K'
            } else {
              return val
            }
          }
        },
        plotOptions: {
          bar: {
            horizontal: horizontal
          }
        },
        xaxis: {
          categories: categories
        },
        fill: {
          opacity: 1
        },
        colors: ['#008FFB', '#80c7fd', '#00E396', '#80f1cb'],
        yaxis: {
          labels: {
            formatter: (val) => {
              if (val >= 1000) {
                return val
              } else {
                return val
              }
            }
          }
        },
        legend: {
          position: 'top',
          horizontalAlign: 'left',
          offset: 40
        }
      };

      var chart = new ApexCharts(document.querySelector("#fuel-stats-chart"), options);
      chart.render();

      window.fuelStatsChart = chart
    })
  }
}

Hooks.DrawerHook = {
  options() {
    return {
      placement: 'right',
      backdrop: true,
      bodyScrolling: false,
      edge: false,
      edgeOffset: '',
      backdropClasses:
        'bg-gray-900/50 dark:bg-gray-900/80 fixed inset-0 z-30',
      onHide: () => {
        console.log('drawer is hidden');
      },
      onShow: () => {
        console.log('drawer is shown');
      },
      onToggle: () => {
        console.log('drawer has been toggled');
      }
    }
  },
  mounted() {
    thisContext = this
    thisElement = this.el

    const $targetElId = thisElement.getAttribute('data-drawer-target')
    const drawer = new Drawer(document.getElementById($targetElId), this.options());
    thisElement.addEventListener('click', () => {
      drawer.show();
    });

  }
}

const calculateRemainingTime = (toDate, fromDate = moment(), units = ['y', 'mo', 'w', 'd']) => {
  const dueDate = moment(toDate);
  const duration = moment.duration(dueDate.diff(fromDate));

  if (duration.asMilliseconds() <= 0) {
    return 'Expired';
  } else {
    const humanizedDuration = humanizeDuration(duration, {
      units: units,
      round: true,
    });
    return `${humanizedDuration} remaining`;
  }
};

Hooks.RemainingTimeHook = {
  mounted() {
    const element = this.el;
    const toDate = element.textContent.trim();

    const timeReminaining = calculateRemainingTime(toDate);

    element.textContent = timeReminaining;
    element.classList.remove("invisible");

  },

  updated() {
    this.mounted()
  },
};


export default Hooks;
