import Event from "../models/Event.js";
import Room from "../models/Room.js";
import { GoogleGenerativeAI } from "@google/generative-ai";

export const chatWithAi = async (req, res) => {
    try {
        // Check if req.body exists
        if (!req.body) {
            return res.status(400).json({ error: 'Request body is missing' });
        }

        const { budget, preferences, lengthOfStay } = req.body;

        // Validate inputs
        if (!budget || typeof budget !== 'number' || budget <= 0) {
            return res.status(400).json({ error: 'Budget should be a positive number' });
        }
        if (!preferences || typeof preferences !== 'object') {
            return res.status(400).json({ error: 'Invalid or missing preferences' });
        }
        if (!lengthOfStay || typeof lengthOfStay !== 'number' || lengthOfStay <= 0) {
            return res.status(400).json({ error: 'Invalid or missing length of stay' });
        }

        // Fetch available rooms and events
        const availableRooms = await Room.find({ isAvailable: true }).lean();
        const availableEvents = await Event.find({ status: "open" }).lean();

        // Calculate minimum budget
        const minRoomPrice = availableRooms.length > 0
            ? Math.min(...availableRooms.map(room => room.pricePerNight)) * lengthOfStay
            : Infinity;
        const minEventPrice = availableEvents.length > 0
            ? Math.min(...availableEvents.map(event => event.price))
            : Infinity;
        const minBudget = minRoomPrice + (minEventPrice * lengthOfStay);

        // If no rooms or events are available, return error
        if (minBudget === Infinity) {
            return res.status(400).json({
                success: false,
                error: 'No rooms or events available to create a plan',
            });
        }

        // Extract preferences
        const { roomType, amenities, eventInterests } = preferences;

        // Construct prompt for AI
        const prompt = `
        You are an AI assistant for a hotel booking and event planning system. A user has provided:
        - Requested Budget: $${budget} for ${lengthOfStay} night(s).
        - Preferred room type: ${roomType || 'Any'}.
        - Preferred amenities: ${amenities?.join(', ') || 'None specified'}.
        - Event interests: ${eventInterests?.join(', ') || 'Any'}.

        Available rooms:
        ${availableRooms.length > 0 ? availableRooms
            .map(
                (room) =>
                    `- ${room.roomType} (ID: ${room._id}), $${room.pricePerNight}/night, Amenities: ${room.amenities.join(', ')}`
            )
            .join('\n') : 'No rooms available'}

        Available events:
        ${availableEvents.length > 0 ? availableEvents
            .map(
                (event) =>
                    `- ${event.eventName} (ID: ${event._id}), Date: ${new Date(event.eventDate).toLocaleDateString('en-US')}, Cost: $${event.price}, Type: ${event.eventName}`
            )
            .join('\n') : 'No events available'}

        Task:
        1. Calculate the minimum budget as the cost of the cheapest room for ${lengthOfStay} night(s) plus the cheapest event for each of ${lengthOfStay} day(s).
        2. If the requested budget is less than the minimum budget, use the minimum budget to generate a plan.
        3. Select the best room within the used budget (requested or minimum) and preferences.
        4. Create a daily event plan for ${lengthOfStay} day(s), choosing one event per day aligned with user interests, within the remaining used budget.
        5. Return a strict JSON response (no extra text or markdown) with:
            - success: true
            - usedBudget: the actual budget used (requested or minimum)
            - budgetAdjusted: boolean (true if minimum budget was used)
            - room: { id: string, type: string, totalCost: number }
            - events: [{ day: number, eventName: string, id: string, date: string (MM/DD/YYYY), cost: number }]
            - Avoid duplicate events unless necessary.
            - Return empty room/events if no suitable options are found.
            - Use provided event IDs.

        Response format:
        {
            "success": true,
            "usedBudget": number,
            "budgetAdjusted": boolean,
            "room": { "id": string, "type": string, "totalCost": number },
            "events": [{ "day": number, "eventName": string, "id": string, "date": string, "cost": number }]
        }
        `;

        // Initialize Google Generative AI
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({
            model: 'gemini-1.5-flash',
            apiVersion: 'v1beta',
        });

        // Call Gemini API
        const result = await model.generateContent(prompt);
        const responseText = result.response.text();
        console.log('Raw Gemini response:', responseText);

        let parsedResult;
        try {
            // Extract JSON content, removing markdown or trailing text
            const jsonMatch = responseText.match(/{[\s\S]*}/);
            if (!jsonMatch) {
                throw new Error('No valid JSON found in response');
            }
            const cleanedText = jsonMatch[0].trim();
            console.log('Cleaned Gemini response:', cleanedText);
            parsedResult = JSON.parse(cleanedText);
        } catch (error) {
            console.error('Error parsing Gemini response:', error.message);
            // Fallback plan with minBudget
            return res.status(200).json({
                success: true,
                usedBudget: minBudget,
                budgetAdjusted: budget < minBudget,
                data: {
                    room: {},
                    events: [],
                },
                message: `Generated with minimum budget of $${minBudget} due to AI response error`,
            });
        }

        // Validate response structure
        if (!parsedResult.success || !parsedResult.usedBudget || typeof parsedResult.budgetAdjusted !== 'boolean' || !parsedResult.room || !parsedResult.events) {
            console.error('Invalid AI response structure:', parsedResult);
            return res.status(500).json({ error: 'Invalid AI response format' });
        }

        // Fetch detailed room data
        let roomDetails = {};
        if (parsedResult.room.id) {
            const room = await Room.findById(parsedResult.room.id).lean();
            if (room) {
                roomDetails = {
                    id: room._id,
                    type: room.roomType,
                    pricePerNight: room.pricePerNight,
                    amenities: room.amenities,
                    images: room.images,
                    totalCost: parsedResult.room.totalCost,
                };
            } else {
                roomDetails = {
                    id: parsedResult.room.id,
                    type: parsedResult.room.type,
                    totalCost: parsedResult.room.totalCost,
                };
            }
        }

        // Fetch detailed event data and ensure dates are in English
        const eventDetails = await Promise.all(
            parsedResult.events.map(async (event) => {
                let eventData;
                if (event.id) {
                    eventData = await Event.findById(event.id).lean();
                }
                if (!eventData) {
                    eventData = availableEvents.find(e => e.eventName.toLowerCase() === event.eventName.toLowerCase());
                }
                return eventData
                    ? {
                          day: event.day,
                          eventName: event.eventName,
                          id: eventData._id,
                          date: new Date(eventData.eventDate).toLocaleDateString('en-US'),
                          cost: event.cost,
                          description: eventData.description,
                          location: eventData.location,
                          images: eventData.images,
                      }
                    : {
                          day: event.day,
                          eventName: event.eventName,
                          id: null,
                          date: new Date(event.date).toLocaleDateString('en-US'),
                          cost: event.cost,
                      };
            })
        );

        // Return response to client
        res.status(200).json({
            success: true,
            usedBudget: parsedResult.usedBudget,
            budgetAdjusted: parsedResult.budgetAdjusted,
            data: {
                room: roomDetails,
                events: eventDetails,
            },
        });
    } catch (error) {
        console.error('Error in chatbot controller:', error.message);
        res.status(500).json({ error: 'Internal server error' });
    }
};