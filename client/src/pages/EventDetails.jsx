import React, { useEffect, useState } from 'react';
import { assets } from '../assets/assets';
import { useAppContext } from '../context/AppContext';
import { useParams } from 'react-router-dom';
import axios from 'axios';
import toast from 'react-hot-toast';

const EventDetails = () => {
    const { id } = useParams();
    const {  currency, getToken } = useAppContext();

    const [event, setEvent] = useState(null);
    const [mainImage, setMainImage] = useState(null);
    const [isAvailable, setIsAvailable] = useState(false);

    // Check if the Event is Available
    const checkAvailability = async () => {
        try {
            const { data } = await axios.post(
                '/api/event/check-availability',
                { eventId: id },
                { headers: { Authorization: `Bearer ${await getToken()}` } }
            );
            if (data.success) {
                if (data.isAvailable) {
                    setIsAvailable(true);
                    toast.success('Event has available seats');
                } else {
                    setIsAvailable(false);
                    toast.error('Event is fully booked or already booked by you');
                }
            } else {
                toast.error(data.message);
            }
        } catch (error) {
            toast.error(error.message);
        }
    };

    // onSubmitHandler function to check availability & book the event
    const onSubmitHandler = async (e) => {
        e.preventDefault();
        try {
            if (!isAvailable) {
                return checkAvailability();
            }
            const { data } = await axios.post(
                `/api/event/book/${id}`,
                {},
                { headers: { Authorization: `Bearer ${await getToken()}` } }
            );
            if (data.success) {
                toast.success(data.message);
                window.scrollTo(0, 0);
            } else {
                toast.error(data.message);
            }
        } catch (error) {
            toast.error(error.message);
        }
    };

    useEffect(() => {
        const fetchEvent = async () => {
            try {
                const { data } = await axios.get(`/api/event/${id}`);
                if (data.success) {
                    setEvent(data.event);
                    setMainImage(data.event.images[0]);
                } else {
                    toast.error(data.message);
                }
            } catch (error) {
                toast.error(error.message);
            }
        };
        fetchEvent();
    }, [id]);

    return event && (
        <div className='py-28 md:py-35 px-4 md:px-16 lg:px-24 xl:px-32'>
            {/* Event Details */}
            <div className='flex flex-col md:flex-row items-start md:items-center gap-2'>
                <h1 className='text-3xl md:text-4xl font-playfair'>{event.eventName}</h1>
                <p className='text-xs font-inter py-1.5 px-3 text-white bg-orange-500 rounded-full'>Limited Seats</p>
            </div>
            <div className='flex items-center gap-1 mt-2'>
                <p className='ml-2'>100+ attendees</p>
            </div>
            <div className='flex items-center gap-1 text-gray-500 mt-2'>
                <img src={assets.locationIcon} alt='location-icon' />
                <span>{event.location}</span>
            </div>

            {/* Event Images */}
            <div className='flex flex-col lg:flex-row mt-6 gap-6'>
                <div className='lg:w-1/2 w-full'>
                    <img className='w-full rounded-xl shadow-lg object-cover'
                        src={mainImage} alt='Event Image' />
                </div>
                <div className='grid grid-cols-2 gap-4 lg:w-1/2 w-full'>
                    {event.images.length > 1 &&
                        event.images.map((image, index) => (
                            <img
                                key={index}
                                onClick={() => setMainImage(image)}
                                className={`w-full rounded-xl shadow-md object-cover cursor-pointer ${
                                    mainImage === image && 'outline-3 outline-orange-500'
                                }`}
                                src={image}
                                alt='Event Image'
                            />
                        ))}
                </div>
            </div>

            {/* Event Highlights */}
            <div className='flex flex-col md:flex-row md:justify-between mt-10'>
                <div className='flex flex-col'>
                    <h1 className='text-3xl md:text-4xl font-playfair'>Join the Experience</h1>
                    <p className='text-base mt-2 text-gray-700'>{event.description}</p>
                </div>
                {/* Event Price */}
                <p className='text-2xl font-medium'>
                    {currency}
                    {event.price}/person
                </p>
            </div>

            {/* Booking Form */}
            <form
                onSubmit={onSubmitHandler}
                className='flex flex-col md:flex-row items-start md:items-center justify-between bg-white shadow-[0px_0px_20px_rgba(0,0,0,0.15)] p-6 rounded-xl mx-auto mt-16 max-w-6xl'
            >
                <div className='flex flex-col flex-wrap md:flex-row items-start md:items-center gap-4 md:gap-10 text-gray-500'>
                    <p className='text-base'>Click to check availability and book your spot.</p>
                </div>
                <button
                    type='submit'
                    className='bg-primary hover:bg-primary-dull active:scale-95 transition-all text-white rounded-md max-md:w-full max-md:mt-6 md:px-25 py-3 md:py-4 text-base cursor-pointer'
                >
                    {isAvailable ? 'Book Now' : 'Check Availability'}
                </button>
            </form>

            {/* Event Specifications */}
            <div className='mt-25 space-y-4'>
                <div className='flex items-center gap-2'>
                    <img className='w-6.5' src={assets.calendarIcon} alt='calendar-icon' />
                    <div>
                        <p className='text-base'>Event Date</p>
                        <p className='text-gray-500'>{new Date(event.eventDate).toLocaleDateString()}</p>
                    </div>
                </div>
                <div className='flex items-center gap-2'>
                    <img className='w-6.5' src={assets.locationIcon} alt='location-icon' />
                    <div>
                        <p className='text-base'>Location</p>
                        <p className='text-gray-500'>{event.location}</p>
                    </div>
                </div>
                <div className='flex items-center gap-2'>
                    <img className='w-6.5' src={assets.seatIcon} alt='seat-icon' />
                    <div>
                        <p className='text-base'>Available Seats</p>
                        <p className='text-gray-500'>
                            {event.capacity - event.bookedBy.length} / {event.capacity}
                        </p>
                    </div>
                </div>
            </div>

            <div className='max-w-3xl border-y border-gray-300 my-15 py-10 text-gray-500'>
                <p>
                    {event.description} This event offers a unique opportunity to engage with{' '}
                    {event.eventName.toLowerCase()} in a vibrant setting. Limited seats are available, so
                    book early to secure your spot!
                </p>
            </div>
        </div>
    );
};

export default EventDetails;