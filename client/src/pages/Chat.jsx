import React, { useEffect, useState } from 'react';
import { assets } from '../assets/assets'; // Adjust path as needed
import { useAppContext } from '../context/AppContext';
import axios from 'axios';
import toast from 'react-hot-toast';

const Chat = () => {

    const {  currency, getToken } = useAppContext();

    
    const [plan, setPlan] = useState(null);
    const [mainImage, setMainImage] = useState(null);
    const [budget, setBudget] = useState(1000);
    const [lengthOfStay, setLengthOfStay] = useState(1);
    const [roomType, setRoomType] = useState('');
    const [amenities, setAmenities] = useState([]);
    const [eventInterestsText, setEventInterestsText] = useState('');
    const [showModal, setShowModal] = useState(false);
    const [modalMessage, setModalMessage] = useState('');
    
    // Available options for preferences
    const roomTypes = ['Double Bed', 'Single Bed', 'Suite', 'Deluxe'];
    const availableAmenities = ['Free WiFi', 'Free Breakfast', 'Pool', 'Gym'];

    // Fetch existing plan
    useEffect(() => {
        const fetchPlan = async () => {
            try {
                const { data } = await axios.get('/api/chat');
                if (data.success && data.data) {
                    setPlan(data.data);
                    setMainImage(data.data.room.images?.[0] || data.data.events?.[0]?.images?.[0]);
                } else {
                    toast.error(data.message || 'No plan found');
                }
            } catch (error) {
                console.error(error.message || 'Failed to load plan');
            }
        };
        fetchPlan();
    }, []);

    // Handle form submission to generate new plan
    const onSubmitHandler = async (e) => {
        e.preventDefault();
        try {
            // Parse event interests from text input
            const eventInterests = eventInterestsText
                .split(',')
                .map(interest => interest.trim())
                .filter(interest => interest.length > 0);

            const requestBody = {
                budget,
                preferences: { roomType, amenities, eventInterests },
                lengthOfStay,
            };
            console.log('Sending request:', requestBody);
            const { data } = await axios.post('/api/chat', requestBody, {
                headers: { Authorization: `Bearer ${await getToken()}` }
            });
            if (data.success) {
                setPlan(data.data);
                setMainImage(data.data.room.images?.[0] || data.data.events?.[0]?.images?.[0]);
   
                // Calculate total budget
                const calculatedBudget = data.data.room.totalCost + 
                    (data.data.events?.reduce((sum, event) => sum + event.cost, 0) || 0);


                if (data.message) {
                    // Handle fallback plan due to parsing error
                    setModalMessage(data.message);
                    setShowModal(true);

                } else if (calculatedBudget > budget && calculatedBudget - budget > 1000) {
                    setModalMessage(`The lowest available budget is ${currency}${calculatedBudget}. A plan has been generated using this budget.`);
                    setShowModal(true);
                }else {
                    toast.success('Plan generated successfully');
                }
            } else {
                toast.error(data.error || 'Failed to generate plan');
            }
        } catch (error) {
            console.error('Frontend error:', error.response?.data || error.message);

            console.error(error.response?.data?.error || error.message);

        }
    };

    // Close modal
    const closeModal = () => {
        setShowModal(false);
        toast.success('Plan generated successfully');
    };

    return (
        <div className='py-28 md:py-35 px-4 md:px-16 lg:px-24 xl:px-32'>
            {/* Modal Popup */}
            {showModal && (
                <div className='fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'>
                    <div className='bg-white p-6 rounded-xl shadow-lg max-w-md w-full'>
                        <h2 className='text-xl font-playfair mb-4'>Budget Adjusted</h2>
                        <p className='text-gray-700 mb-4'>{modalMessage}</p>
                        <button
                            onClick={closeModal}
                            className='bg-primary hover:bg-primary-dull text-white px-4 py-2 rounded-md'
                        >
                            OK
                        </button>
                    </div>
                </div>
            )}

            {/* Plan Header */}
            <div className='flex flex-col md:flex-row items-start md:items-center gap-2'>
                <h1 className='text-3xl md:text-4xl font-playfair'>Your Personalized Travel Plan</h1>
                <p className='text-xs font-inter py-1.5 px-3 text-white bg-orange-500 rounded-full'>Customized</p>
            </div>
            <div className='flex items-center gap-1 mt-2'>
                <p className='ml-2'>Tailored to your preferences</p>
            </div>

            {/* Plan Images */}
            {plan && (
                <div className='flex flex-col lg:flex-row mt-6 gap-6'>
                    <div className='lg:w-1/2 w-full'>
                        <img
                            className='w-full rounded-xl shadow-lg object-cover'
                            src={mainImage}
                            alt='Plan Image'
                        />
                    </div>
                    <div className='grid grid-cols-2 gap-4 lg:w-1/2 w-full'>
                        {[...(plan.room.images || []), ...(plan.events?.[0]?.images || [])].slice(0, 4).map((image, index) => (
                            <img
                                key={index}
                                onClick={() => setMainImage(image)}
                                className={`w-full rounded-xl shadow-md object-cover cursor-pointer ${mainImage === image && 'outline-3 outline-orange-500'}`}
                                src={image}
                                alt='Plan Image'
                            />
                        ))}
                    </div>
                </div>
            )}

            {/* Plan Highlights */}
            {plan && (
                <div className='flex flex-col md:flex-row md:justify-between mt-10'>
                    <div className='flex flex-col'>
                        <h1 className='text-3xl md:text-4xl font-playfair'>Your Perfect Stay & Activities</h1>
                        <p className='text-base mt-2 text-gray-700'>
                            A curated plan with a {plan.room.type} room and exciting events tailored to your interests.
                        </p>
                    </div>
                    <p className='text-2xl font-medium'>{currency}{plan.room.totalCost} total</p>
                </div>
            )}

            {/* Plan Form */}
            <form onSubmit={onSubmitHandler} className='flex flex-col md:flex-row items-start md:items-center justify-between bg-white shadow-[0px_0px_20px_rgba(0,0,0,0.15)] p-6 rounded-xl mx-auto mt-16 max-w-6xl'>
                <div className='flex flex-col flex-wrap md:flex-row items-start md:items-center gap-4 md:gap-10 text-gray-500'>
                    <div className='flex flex-col'>
                        <label htmlFor='budget' className='font-medium'>Budget ({currency})</label>
                        <input
                            id='budget'
                            type='number'
                            min='1'
                            value={budget}
                            onChange={(e) => setBudget(Number(e.target.value))}
                            className='max-w-32 rounded border border-gray-300 px-3 py-2 mt-1.5 outline-none'
                            required
                        />
                    </div>
                    <div className='flex flex-col'>
                        <label htmlFor='lengthOfStay' className='font-medium'>Length of Stay (days)</label>
                        <input
                            id='lengthOfStay'
                            type='number'
                            min='1'
                            value={lengthOfStay}
                            onChange={(e) => setLengthOfStay(Number(e.target.value))}
                            className='max-w-20 rounded border border-gray-300 px-3 py-2 mt-1.5 outline-none'
                            required
                        />
                    </div>
                    <div className='flex flex-col'>
                        <label htmlFor='roomType' className='font-medium'>Room Type</label>
                        <select
                            id='roomType'
                            value={roomType}
                            onChange={(e) => setRoomType(e.target.value)}
                            className='rounded border border-gray-300 px-3 py-2 mt-1.5 outline-none'
                        >
                            <option value=''>Any</option>
                            {roomTypes.map((type) => (
                                <option key={type} value={type}>{type}</option>
                            ))}
                        </select>
                    </div>
                    <div className='flex flex-col'>
                        <label className='font-medium'>Amenities</label>
                        <div className='flex flex-wrap gap-2 mt-1.5'>
                            {availableAmenities.map((amenity) => (
                                <label key={amenity} className='flex items-center gap-1 text-sm'>
                                    <input
                                        type='checkbox'
                                        checked={amenities.includes(amenity)}
                                        onChange={(e) => {
                                            if (e.target.checked) {
                                                setAmenities([...amenities, amenity]);
                                            } else {
                                                setAmenities(amenities.filter((a) => a !== amenity));
                                            }
                                        }}
                                    />
                                    {amenity}
                                </label>
                            ))}
                        </div>
                    </div>
                    <div className='flex flex-col'>
                        <label htmlFor='eventInterests' className='font-medium'>Event Interests (comma-separated)</label>
                        <input
                            id='eventInterests'
                            type='text'
                            value={eventInterestsText}
                            onChange={(e) => setEventInterestsText(e.target.value)}
                            className='rounded border border-gray-300 px-3 py-2 mt-1.5 outline-none'
                            placeholder='e.g., Historical City Tour, Kayaking Adventure'
                        />
                    </div>
                </div>
                <button
                    type='submit'
                    className='bg-primary hover:bg-primary-dull active:scale-95 transition-all text-white rounded-md max-md:w-full max-md:mt-6 md:px-25 py-3 md:py-4 text-base cursor-pointer'
                >
                    Generate Plan
                </button>
            </form>

            {/* Plan Specifications */}
            {plan && (
                <div className='mt-25 space-y-4'>
                    <div className='flex items-start gap-2'>
                        <img className='w-6.5' src={assets.roomIcon || assets.locationIcon} alt='room-icon' />
                        <div>
                            <p className='text-base'>Room Details</p>
                            <p className='text-gray-500'>{plan.room.type} - {currency}{plan.room.pricePerNight}/night</p>
                            <p className='text-gray-500'>Amenities: {plan.room.amenities?.join(', ') || 'None'}</p>
                        </div>
                    </div>
                    {plan.events.map((event) => (
                        <div key={event.day} className='flex items-start gap-2'>
                            <img className='w-6.5' src={assets.calendarIcon} alt='calendar-icon' />
                            <div>
                                <p className='text-base'>Day {event.day}: {event.eventName}</p>
                                <p className='text-gray-500'>Date: {event.date}</p>
                                <p className='text-gray-500'>Cost: {currency}{event.cost}</p>
                                <p className='text-gray-500'>Location: {event.location}</p>
                                <p className='text-gray-500'>{event.description}</p>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Plan Description */}
            {plan && (
                <div className='max-w-3xl border-y border-gray-300 my-15 py-10 text-gray-500'>
                    <p>
                        This personalized travel plan includes a stay in a {plan.room.type} room and a curated selection of events like {plan.events.map(e => e.eventName).join(', ')}. 
                        Book now to enjoy a tailored experience!
                    </p>
                </div>
            )}
        </div>
    );
};

export default Chat;