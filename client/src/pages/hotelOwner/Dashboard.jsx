import React, { useEffect, useState } from 'react'
import { assets } from '../../assets/assets'
import Title from '../../components/Title';
import { useAppContext } from '../../context/AppContext';
import toast from 'react-hot-toast';

const Dashboard = () => {
    const { currency, user, getToken, axios } = useAppContext();

    const [dashboardData, setDashboardData] = useState({
        bookings: [],
        totalBookings: 0,
        totalRevenue: 0,
    });

    const fetchDashboardData = async () => {
        try {
            const { data } = await axios.get('/api/bookings/hotel', { 
                headers: { Authorization: `Bearer ${await getToken()}` } 
            });
            if (data.success) {
                setDashboardData(data.dashboardData);
            } else {
                toast.error(data.message || 'Failed to fetch dashboard data');
            }
        } catch (error) {
            toast.error(error.message || 'Failed to fetch dashboard data');
        }
    }

    const handleDeleteBooking = async (bookingId) => {
        if (!window.confirm('Are you sure you want to cancel this booking?')) return;
        
        try {
            const { data } = await axios.delete(`/api/bookings/cancel/${bookingId}`, {
                headers: { Authorization: `Bearer ${await getToken()}` }
            });
            if (data.success) {
                toast.success(data.message || 'Booking cancelled successfully');
                // Optimistically update state to remove the deleted booking
                setDashboardData(prev => ({
                    ...prev,
                    bookings: prev.bookings.filter(booking => booking._id !== bookingId),
                    totalBookings: prev.totalBookings - 1,
                    totalRevenue: prev.totalRevenue - (prev.bookings.find(b => b._id === bookingId)?.totalPrice || 0)
                }));
                // Fetch fresh data to ensure consistency
                await fetchDashboardData();
        
            
            } else {
                toast.error(data.message || 'Failed to cancel booking');
            }
        } catch (error) {
            const errorMessage = error.response?.data?.message || error.message || 'An error occurred while cancelling the booking';
            toast.error(errorMessage);
        }
    }

    useEffect(() => {
        if (user) {
            fetchDashboardData();
        }
    }, [user]);

    return (
        <div>
            <Title align='left' font='outfit' title='Dashboard' subTitle='Monitor your room listings, track bookings and analyze revenue—all in one place. Stay updated with real-time insights to ensure smooth operations.' />
            <div className='flex gap-4 my-8'>
                <div className='bg-primary/3 border border-primary/10 rounded flex p-4 pr-8'>
                    <img className='max-sm:hidden h-10' src={assets.totalBookingIcon} alt="" />
                    <div className='flex flex-col sm:ml-4 font-medium'>
                        <p className='text-blue-500 text-lg'>Total Bookings</p>
                        <p className='text-neutral-400 text-base'>{ dashboardData.totalBookings }</p>
                    </div>
                </div>
                <div className='bg-primary/3 border border-primary/10 rounded flex p-4 pr-8'>
                    <img className='max-sm:hidden h-10' src={assets.totalRevenueIcon} alt="" />
                    <div className='flex flex-col sm:ml-4 font-medium'>
                        <p className='text-blue-500 text-lg'>Total Revenue</p>
                        <p className='text-neutral-400 text-base'>{currency} { dashboardData.totalRevenue }</p>
                    </div>
                </div>
            </div>

            <h2 className='text-xl text-blue-950/70 font-medium mb-5'>Recent Bookings</h2>
            <div className='w-full max-w-3xl text-left border border-gray-300 rounded-lg max-h-80 overflow-y-scroll'>
                <table className='w-full' >
                    <thead className='bg-gray-50'>
                        <tr>
                            <th className='py-3 px-4 text-gray-800 font-medium'>User Name</th>
                            <th className='py-3 px-4 text-gray-800 font-medium max-sm:hidden'>Room Name</th>
                            <th className='py-3 px-4 text-gray-800 font-medium text-center'>Total Amount</th>
                            <th className='py-3 px-4 text-gray-800 font-medium text-center'>Payment Status</th>
                            <th className='py-3 px-4 text-gray-800 font-medium text-center'>Action</th>
                        </tr>
                    </thead>
                    <tbody className='text-sm'>
                        {
                            dashboardData.bookings.map((item) => (
                                <tr key={item._id}>
                                    <td className='py-3 px-4 text-gray-700 border-t border-gray-300'>{item.user.username}</td>
                                    <td className='py-3 px-4 text-gray-400 border-t border-gray-300 max-sm:hidden'>{item.room.roomType}</td>
                                    <td className='py-3 px-4 text-gray-400 border-t border-gray-300 text-center'>{currency} {item.totalPrice}</td>
                                    <td className='py-3 px-4 border-t border-gray-300 flex'>
                                        <button className={`py-1 px-3 text-xs rounded-full mx-auto ${item.isPaid ? "bg-green-200 text-green-600" : "bg-amber-200 text-yellow-600"}`}>
                                            {item.isPaid ? "Completed" : "Pending"}
                                        </button>
                                    </td>
                                    <td className='py-3 px-4 border-t border-gray-300 text-center'>
                                        <button 
                                            onClick={() => handleDeleteBooking(item._id)}
                                            className='py-1 px-3 text-xs rounded-full bg-red-200 text-red-600 hover:bg-red-300'
                                        >
                                            Cancel
                                        </button>
                                    </td>
                                </tr>
                            ))
                        }
                    </tbody>
                </table>
            </div>
        </div>
    )
}

export default Dashboard