// controllers/landlordDashboardController.js

import Property from '../models/Property.js';
import Contract from '../models/Contract.js';
import Payment from '../models/Payment.js';
import MaintenanceRequest from '../models/MaintenanceRequest.js';

export const getLandlordDashboardStats = async (req, res) => {
  try {
    const landlordId = req.user._id;

    const [
      totalProperties,
      availableProperties,
      rentedProperties,
      totalContracts,
      activeContracts,
      pendingMaintenance,
    ] = await Promise.all([
      Property.countDocuments({ ownerId: landlordId }),
      Property.countDocuments({ ownerId: landlordId, status: 'available' }),
      Property.countDocuments({ ownerId: landlordId, status: 'rented' }),
      Contract.countDocuments({ landlordId: landlordId }),
      Contract.countDocuments({ landlordId: landlordId, status: 'active' }),
      MaintenanceRequest.countDocuments({ 
        propertyId: { $in: await Property.find({ ownerId: landlordId }).select('_id') },
        status: 'pending' 
      }),
    ]);

    const paymentStats = await Payment.aggregate([
      {
        $lookup: {
          from: 'contracts',
          localField: 'contractId',
          foreignField: '_id',
          as: 'contractInfo',
        },
      },
      { $unwind: '$contractInfo' },
      { $match: { 'contractInfo.landlordId': landlordId, status: 'paid' } },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$amount' },
          totalPayments: { $sum: 1 },
        },
      },
    ]);

    const totalRevenue = paymentStats[0]?.totalRevenue || 0;

    // --- Latest Activities ---
    const latestContracts = await Contract.find({ landlordId })
      .sort({ createdAt: -1 })
      .limit(5)
      .populate('propertyId', 'title')
      .populate('tenantId', 'name');

    const latestPayments = await Payment.find({ contractId: { $in: await Contract.find({ landlordId }).select('_id') } })
        .sort({ createdAt: -1 })
        .limit(5)
        .populate({
            path: 'contractId',
            populate: { path: 'tenantId', select: 'name' }
        });


    res.status(200).json({
      summary: {
        totalProperties,
        availableProperties,
        rentedProperties,
        totalContracts,
        activeContracts,
        pendingMaintenance,
        totalRevenue,
      },
      latest: {
        contracts: latestContracts,
        payments: latestPayments,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Error fetching landlord dashboard', error: error.message });
  }
};