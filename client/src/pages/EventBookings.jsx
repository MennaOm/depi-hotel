import React, { useEffect, useState } from 'react';
import Title from '../components/Title';
import { assets } from '../assets/assets';
import { useAppContext } from '../context/AppContext';
import toast from 'react-hot-toast';

const EventBookings = () => {
    const { axios, getToken, user } = useAppContext();
    const [events, setEvents] = useState([]);

    const fetchUserEventBookings = async () => {
        try {
            const { data } = await axios.get('/api/event/bookings', {
                headers: { Authorization: `Bearer ${await getToken()}` }
            });
            console.log(data)
            if (data.success) {
                setEvents(data.events);
            } else {
                toast.error(data.message || 'Failed to fetch event bookings');
            }
        } catch (error) {
            console.error(error.message || 'Failed to fetch event bookings');
        }
    };

    const handleCancelBooking = async (eventId) => {
        if (!window.confirm('Are you sure you want to cancel this event booking?')) return;

        try {
            const { data } = await axios.delete(`/api/event/cancel/${eventId}`, {
                headers: { Authorization: `Bearer ${await getToken()}` }
            });
            if (data.success) {
                toast.dismiss();
                toast.success(data.message || 'Event booking cancelled successfully');
                // Optimistically update state to remove the cancelled event
                setEvents(prev => prev.filter(event => event._id !== eventId));
                // Fetch fresh data to ensure consistency
                await fetchUserEventBookings();
            } else {
                console.error(data.message || 'Failed to cancel event booking');
                await fetchUserEventBookings();
            }
        } catch (error) {
            const errorMessage = error.response?.data?.message || error.message || 'An error occurred while cancelling the event booking';
            console.error(errorMessage);
        }
    };

    useEffect(() => {
        if (user) {
            fetchUserEventBookings();
        }
    }, [user]);

    return (
        <div className='py-28 md:pb-35 md:pt-32 px-4 md:px-16 lg:px-24 xl:px-32'>
            <Title
                title='My Event Bookings'
                subTitle='Easily manage your past, current, and upcoming event reservations in one place. Plan your experiences seamlessly with just a few clicks'
                align='left'
            />
            <div className="max-w-6xl mt-8 w-full text-gray-800">
                <div className="hidden md:grid md:grid-cols-[3fr_2fr_1fr] w-full border-b border-gray-300 font-medium text-base py-3">
                    <div className="w-1/3">Events</div>
                    <div className="w-1/3">Date & Location</div>
                    <div className="w-1/3">Actions</div>
                </div>

                {events.length === 0 ? (
                    <p className="text-gray-500 text-center py-6">No event bookings found.</p>
                ) : (
                    events.map((event) => (
                        <div key={event._id} className="grid grid-cols-1 md:grid-cols-[3fr_2fr_1fr] w-full border-b border-gray-300 py-6 first:border-t">
                            <div className="flex flex-col md:flex-row">
                                <img
                                    className="min-md:w-44 rounded shadow object-cover"
                                    src={event.images[0]}
                                    alt="event-img"
                                />
                                <div className="flex flex-col gap-1.5 max-md:mt-3 min-md:ml-4">
                                    <p className="font-playfair text-2xl">
                                        {event.eventName}
                                    </p>
                                    <div className="flex items-center gap-1 text-sm text-gray-500">
                                        <img src={assets.locationIcon} alt="location-icon" />
                                        <span>{event.location}</span>
                                    </div>
                                    <p className="text-base">Price: ${event.price}</p>
                                </div>
                            </div>

                            <div className="flex flex-row md:items-center md:gap-12 mt-3 gap-8">
                                <div>
                                    <p>Event Date:</p>
                                    <p className="text-gray-500 text-sm">{new Date(event.eventDate).toDateString()}</p>
                                </div>
                                <div>
                                    <p>Location:</p>
                                    <p className="text-gray-500 text-sm">{event.location}</p>
                                </div>
                            </div>

                            <div className="flex flex-col items-start justify-center pt-3">
                                <button
                                    onClick={() => handleCancelBooking(event._id)}
                                    className="px-4 py-1.5 mt-2 text-xs border border-red-400 text-red-600 rounded-full hover:bg-red-50 transition-all cursor-pointer"
                                >
                                    Cancel
                                </button>
                            </div>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};

export default EventBookings;
