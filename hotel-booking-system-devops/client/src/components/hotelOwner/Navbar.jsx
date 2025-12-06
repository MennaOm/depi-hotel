import React from 'react'
import { UserButton } from '@clerk/clerk-react'
import { Link } from 'react-router-dom'

const Navbar = () => {

    return (
        <div className="flex items-center justify-between px-4 md:px-8 border-b border-gray-300 py-3 bg-white transition-all duration-300">
            <Link to="/">
                <span className="text-xl font-bold text-black">
                    Royal Haven
                </span>
            </Link>
            <UserButton />
        </div>
    )
}

export default Navbar