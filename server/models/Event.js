import mongoose from "mongoose";
const { Schema, model } = mongoose

const eventSchema = new Schema({
    eventName: {
        type: String,
        required: true,
        trim: true
    },
    description: {
        type: String,
        required: true
    },
    eventDate: {
        type: Date,
        required: true
    },
    location: {
        type: String,
        required: true
    },
    price: {
        type: Number,
        required: true,
        min: 0
    },
    capacity: {
        type: Number,
        required: true,
        min: 1
    },
    bookedSeats: {
        type: Number,
        default: 0
    },
    bookedBy: [{
        type:String,
        ref: 'User'
    }],
    status: {
        type: String,
        enum: ['open', 'closed', 'full'],
        default: 'open'
    },
    images: [{ type: String }]
}, { timestamps: true });

const Event = mongoose.models.Events || model('Event', eventSchema);

export default Event