import { useState, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import axios from 'axios';
import { useAppContext } from '../context/AppContext';
import { assets } from '../assets/assets';

const CheckBox = ({ label, selected = false, onChange = () => {} }) => (
    <label className="flex gap-3 items-center cursor-pointer mt-2 text-sm">
        <input type="checkbox" checked={selected} onChange={(e) => onChange(e.target.checked, label)} />
        <span className="font-light select-none">{label}</span>
    </label>
);

const RadioButton = ({ label, selected = false, onChange = () => {} }) => (
    <label className="flex gap-3 items-center cursor-pointer mt-2 text-sm">
        <input type="radio" name="sortOption" checked={selected} onChange={() => onChange(label)} />
        <span className="font-light select-none">{label}</span>
    </label>
);

const AllEvents = () => {
    const [searchParams, setSearchParams] = useSearchParams();
    const { navigate, currency } = useAppContext();

    const [events, setEvents] = useState([]);
    const [openFilters, setOpenFilters] = useState(false);
    const [selectedFilters, setSelectedFilters] = useState({
        type: [],
        priceRange: [],
    });
    const [selectedSort, setSelectedSort] = useState('');

    // Define types and ranges based on API response
    const eventTypes = ['Tour', 'Dining', 'Outdoor', 'Music', 'Art', 'Yoga', 'Food Festival', 'Theater', 'Cooking'];
    const priceRanges = ['0 to 25', '25 to 50', '50 to 75', '75 to 100'];
    const sortOptions = ['Price Low to High', 'Price High to Low', 'Newest First'];

    useEffect(() => {
        const fetchEvents = async () => {
            try {
                const res = await axios.get(`/api/event/`);
                setEvents(res.data.events);
            } catch (err) {
                console.error('Failed to fetch events:', err);
            }
        };
        fetchEvents();
    }, []);

    const handleFilterChange = (checked, value, type) => {
        setSelectedFilters((prev) => {
            const updated = { ...prev };
            if (checked) updated[type].push(value);
            else updated[type] = updated[type].filter((item) => item !== value);
            return updated;
        });
    };

    const handleSortChange = (option) => setSelectedSort(option);

    const matchesType = (event) => {
        const eventTypeMap = {
            'Historical City Tour': 'Tour',
            'Museum Guided Tour': 'Tour',
            'Gourmet Dinner Night': 'Dining',
            'Mountain Hiking': 'Outdoor',
            'Kayaking Adventure': 'Outdoor',
            'Jazz Concert': 'Music',
            'Art Gallery Visit': 'Art',
            'Yoga by the Lake': 'Yoga',
            'Local Food Festival': 'Food Festival',
            'Theater Performance': 'Theater',
            'Cooking Class': 'Cooking'
        };
        return selectedFilters.type.length === 0 || selectedFilters.type.includes(eventTypeMap[event.eventName]);
    };

    const matchesPrice = (event) => {
        return selectedFilters.priceRange.length === 0 || selectedFilters.priceRange.some((range) => {
            const [min, max] = range.split(' to ').map(Number);
            return event.price >= min && event.price <= max;
        });
    };

    const filterDestination = (event) => {
        const destination = searchParams.get('destination');
        if (!destination) return true;
        return event.location?.toLowerCase().includes(destination.toLowerCase());
    };

    const sortEvents = (a, b) => {
        if (selectedSort === 'Price Low to High') return a.price - b.price;
        if (selectedSort === 'Price High to Low') return b.price - a.price;
        if (selectedSort === 'Newest First') return new Date(b.eventDate) - new Date(a.eventDate);
        return 0;
    };

    const filteredEvents = useMemo(() => {
        return events.filter(event =>
            matchesType(event) &&
            matchesPrice(event) &&
            filterDestination(event)
        ).sort(sortEvents);
    }, [events, selectedFilters, selectedSort, searchParams]);

    const clearFilters = () => {
        setSelectedFilters({ type: [], priceRange: [] });
        setSelectedSort('');
        setSearchParams({});
    };

    return (
        <div className='flex flex-col-reverse lg:flex-row items-start justify-between pt-28 md:pt-35 px-4 md:px-16 lg:px-24 xl:px-32'>
            <div>
                <div className="flex flex-col items-start text-left">
                    <h1 className='font-playfair text-4xl md:text-[40px]'>Events</h1>
                    <p className='text-sm md:text-base text-gray-500/90 mt-2 max-w-174'>
                        Discover exciting events tailored to your interests.
                    </p>
                </div>

                {filteredEvents.map((event) => (
                    <div key={event._id} className='flex flex-col md:flex-row items-start py-10 gap-6 border-b border-gray-300 last:pb-30 last:border-0'>
                        <img
                            title='View Event Details'
                            onClick={() => { navigate(`/events/${event._id}`); scrollTo(0, 0); }}
                            src={event.images[0]}
                            alt="event-img"
                            className='max-h-65 md:w-1/2 rounded-xl shadow-lg object-cover cursor-pointer'
                        />
                        <div className='md:w-1/2 flex flex-col gap-2'>
                            <p className='text-gray-500'>{event.location}</p>
                            <p
                                onClick={() => { navigate(`/events/${event._id}`); scrollTo(0, 0); }}
                                className='text-gray-800 text-3xl font-playfair cursor-pointer'
                                title='View Event Details'
                            >
                                {event.eventName}
                            </p>
                            <p className='text-sm text-gray-600'>{new Date(event.eventDate).toLocaleDateString()}</p>
                            <div className='flex items-center gap-1 text-gray-500 mt-2 text-sm'>
                                <img src={assets.locationIcon} alt="location-icon" />
                                <span>{event.location}</span>
                            </div>
                            <p className='text-base mt-2 text-gray-700'>{event.description?.slice(0, 100)}...</p>
                            <p className='text-xl font-medium text-gray-700 mt-2'>{currency}{event.price}</p>
                        </div>
                    </div>
                ))}
            </div>

            <div className="bg-white w-80 border border-gray-300 text-gray-600 max-lg:mb-8 min-lg:mt-16">
                <div className={`flex items-center justify-between px-5 py-2.5 min-lg:border-b border-gray-300 ${openFilters && "border-b"}`}>
                    <p className='text-base font-medium text-gray-800'>FILTERS</p>
                    <div className='text-xs cursor-pointer'>
                        <span onClick={() => setOpenFilters(!openFilters)} className='lg:hidden'>
                            {openFilters ? "HIDE" : "SHOW"}
                        </span>
                        <span onClick={clearFilters} className='hidden lg:block'>CLEAR</span>
                    </div>
                </div>
                <div className={`${openFilters ? "h-auto" : "h-0 lg:h-auto"} overflow-hidden transition-all duration-700`}>
                    <div className='px-5 pt-5'>
                        <p className='font-medium text-gray-800 pb-2'>Event Type</p>
                        {eventTypes.map((type, index) => (
                            <CheckBox key={index} label={type} selected={selectedFilters.type.includes(type)} onChange={(checked) => handleFilterChange(checked, type, 'type')} />
                        ))}
                    </div>
                    <div className='px-5 pt-5'>
                        <p className='font-medium text-gray-800 pb-2'>Price Range</p>
                        {priceRanges.map((range, index) => (
                            <CheckBox key={index} label={`${currency} ${range}`} selected={selectedFilters.priceRange.includes(range)} onChange={(checked) => handleFilterChange(checked, range, 'priceRange')} />
                        ))}
                    </div>
                    <div className="px-5 pt-5 pb-7">
                        <p className="font-medium text-gray-800 pb-2">Sort By</p>
                        {sortOptions.map((option, index) => (
                            <RadioButton key={index} label={option} selected={selectedSort === option} onChange={() => handleSortChange(option)} />
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default AllEvents;