"use client";

import { EventForm } from "../event-form";
import { MapLocationsSection } from "../map-locations-section";

import type { AdminEventDetail } from "@/lib/dto/event";

/** Tab Thông tin & địa điểm — EventForm + bản đồ, tách khỏi page cũ. */
export function EventInfoTab({ event }: { event: AdminEventDetail }) {
  return (
    <div className="flex flex-col gap-6">
      <EventForm initial={event} />
      <hr className="border-border" />
      <MapLocationsSection eventId={event.id} />
    </div>
  );
}
