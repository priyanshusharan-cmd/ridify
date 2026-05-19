# Ridify Ride Matching & Backend Logic Documentation

This document outlines all the scenarios, constraints, and operational logic built into the Ridify ride-sharing backend system, specifically focusing on the lifecycle of a ride and passenger management.

## 1. Ride Search & Visibility
*   **Active Status:** Rides are only visible in "Find a Ride" if their status is `available` or `accepted` and they haven't expired.
*   **Distance Matching (Adaptive Sampling):** For long flexible routes, the system dynamically downsamples the route path to ~100 points to quickly match the user's pickup and drop-off coordinates within the specified search radius.
*   **Exclusion Rules:** A ride is hidden from a searching user if the user has previously been **kicked**, **declined**, or is already a passenger or pending requester on that ride.
*   **Search Capacity Checking:** Search visibility ignores pending requests. A ride will remain visible to users as long as there is physical space remaining based on **accepted** passengers.
*   **Hidden Status:** Once a ride is fully booked (marked `full`) or marked `started`, it completely disappears from search results.

## 2. Requesting a Ride
*   **Eligibility:** Users cannot request a ride if it has been `started`, `completed`, or `cancelled`. Duplicate requests or requests from kicked/declined users are strictly blocked.
*   **Unrestricted Pending Requests:** Pending requests do not occupy physical seats. Multiple users can request the same seat. The system only validates that the requested segment has space remaining against the currently **accepted** passengers. 

## 3. Accepting a Request & Capacity Fullness
*   **Seat Allocation:** When a driver accepts a request, the passenger officially occupies the requested seats for their specific segment.
*   **Smart Auto-Decline:** Upon accepting a passenger, the system evaluates all other pending requests. If any pending requests no longer fit into the remaining physical capacity, they are automatically declined and removed from the requests queue.
*   **Marking as "Full":** 
    *   *Nonstop/Shared-Start:* The ride becomes `full` if the total seats occupied by accepted passengers reaches maximum car capacity.
    *   *Flexible:* The ride becomes `full` if every active segment along the route is booked to maximum capacity. Once marked `full`, it is removed from public search.

## 4. Starting the Ride
*   **Status Update:** The ride's status changes to `started`, instantly hiding it from all new searches.
*   **Auto-Cleaning Pending Requests:** Any requests that are still pending when the driver hits "Start" are automatically declined. The users are added to the declined list and notified via a cancellation event so the request disappears from their active screen.

## 5. Kicking a Passenger
*   **Removal & Blacklisting:** The passenger is removed from all active arrays (`passengers`, `boardedPassengers`, `arrivedAt`) and added to the `kicked` list, meaning they cannot rejoin or search for the ride again.
*   **Dynamic Capacity Restoration:** 
    *   **If the ride HAS NOT started:** The capacity freed up by the kicked passenger reverts the ride's status from `full` back to `accepted` or `available`. This immediately restores the ride in the "Find a Ride" search pool so someone else can book the seat.
    *   **If the ride HAS started:** The seat is visually freed for the driver, but the ride status remains `started`, ensuring it stays hidden from new searches.

## 6. Boarding & Live Ride Constraints
*   **Driver Arrival Check:** The driver can only mark arrival if the ride is `started`. For flexible rides, the system strictly verifies that boarding the passenger right now won't exceed the physical car capacity.
*   **Boarding Validation:** At the moment of boarding, a final capacity check ensures the physical car isn't over capacity.
*   **Drop-off:** Dropping off a passenger removes them from the active occupancy, freeing up that segment's capacity for potential upcoming flexible pickups.

## 7. Ending the Ride
*   **Completion Validation:** For flexible and shared-start rides, the driver cannot end the trip if there are still active passengers who haven't been dropped off. For nonstop rides, ending the trip automatically drops off everyone.
