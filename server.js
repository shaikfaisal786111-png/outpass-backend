const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3001;

// --- Middleware ---
app.use(cors());
app.use(express.json());

// --- ROUTE 0: AUTHENTICATION LOGIN ---
app.post('/api/auth/login', async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: "Email and password are required" });
  }

  try {
    const mentorEmail = process.env.MENTOR_EMAIL || 'mentor@cmrec.edu';
    const mentorPassword = process.env.MENTOR_PASSWORD || 'password123';

    if (email.trim().toLowerCase() === mentorEmail.toLowerCase() && password === mentorPassword) {
      return res.json({
        success: true,
        token: 'mock-jwt-mentor-token-secure-123',
        user: {
          id: 'mentor-01',
          name: 'Faculty Mentor',
          email: mentorEmail,
          role: 'MENTOR'
        }
      });
    }

    return res.status(401).json({ success: false, message: "Invalid email or password" });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ success: false, message: "Server error during login" });
  }
});

// --- MENTOR ROUTE 1: FETCH PENDING OUTPASSES FOR MENTOR ---
app.get('/api/mentor/outpasses', async (req, res) => {
  try {
    const pendingList = await prisma.outpass.findMany({
      where: { status: 'Pending' }
    });
    res.json({ success: true, data: pendingList, outpasses: pendingList });
  } catch (error) {
    console.error("Error fetching mentor outpasses:", error);
    res.status(500).json({ success: false, message: "Failed to fetch mentor queue." });
  }
});

// --- MENTOR ROUTE 2: VERIFY OUTPASS ---
app.put('/api/mentor/outpasses/:id/verify', async (req, res) => {
  try {
    const { id } = req.params;
    
    const existingOutpass = await prisma.outpass.findUnique({ where: { id } });
    if (!existingOutpass) {
      return res.status(404).json({ success: false, message: "Outpass not found." });
    }

    const updatedOutpass = await prisma.outpass.update({
      where: { id },
      data: { status: 'Approved' } 
    });

    res.json({ success: true, message: "Outpass verified successfully", data: updatedOutpass });
  } catch (error) {
    console.error("Error verifying outpass:", error);
    res.status(500).json({ success: false, message: "Server error during verification" });
  }
});

// --- ROUTE 1: CREATE OUTPASS REQUEST ---
app.post('/api/outpass/request', async (req, res) => {
  const { name, rollNo, destination, reason } = req.body;

  if (!name || !rollNo || !destination || !reason) {
    return res.status(400).json({ success: false, message: "All fields are required" });
  }

  try {
    const existingOutpass = await prisma.outpass.findFirst({
      where: {
        rollNo: rollNo,
        status: {
          in: ['Pending', 'Approved']
        }
      }
    });

    if (existingOutpass) {
      return res.status(400).json({ 
        success: false, 
        message: "You already have an active or pending outpass." 
      });
    }

    const newOutpass = await prisma.outpass.create({
      data: {
        name,
        rollNo,
        destination,
        reason,
        status: 'Pending'
      }
    });
    
    res.json({ success: true, message: "Outpass requested successfully", data: newOutpass });
  } catch (error) {
    console.error("Error creating outpass:", error);
    res.status(500).json({ success: false, message: "Server error while creating request" });
  }
});

// --- ROUTE 2: HOD APPROVAL PANEL ---
app.put('/api/outpass/approve/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const existingOutpass = await prisma.outpass.findUnique({ where: { id } });
    if (!existingOutpass) {
      return res.status(404).json({ success: false, message: "Outpass not found in database." });
    }

    const approvedOutpass = await prisma.outpass.update({
      where: { id },
      data: { status: 'Approved' }
    });
    
    res.json({ success: true, message: "Outpass approved successfully", data: approvedOutpass });
  } catch (error) {
    console.error("Error approving outpass:", error);
    res.status(500).json({ success: false, message: "Server error during approval" });
  }
});

// --- ROUTE 3: GUARD VERIFICATION ---
app.put('/api/outpass/verify/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const outpass = await prisma.outpass.findUnique({ where: { id } });

    if (!outpass) {
      return res.status(404).json({ success: false, message: "Invalid Outpass ID." });
    }
    if (outpass.status === 'Used') {
      return res.status(403).json({ success: false, message: "ALERT: Already Scanned! This outpass is expired." });
    }
    if (outpass.status !== 'Approved') {
      return res.status(400).json({ success: false, message: Access Denied. Status is currently:  });
    }

    const updatedOutpass = await prisma.outpass.update({
      where: { id },
      data: { status: 'Used' }
    });

    res.json({ success: true, message: "Valid Outpass! Student may exit.", data: updatedOutpass });
  } catch (error) {
    console.error("Verification error:", error);
    res.status(500).json({ success: false, message: "Server Error during verification" });
  }
});

// --- ROUTE 4: FETCH PENDING OUTPASSES (HOD Panel) ---
app.get('/api/outpass/pending', async (req, res) => {
  try {
    const pendingList = await prisma.outpass.findMany({
      where: { status: 'Pending' }
    });
    res.json({ success: true, data: pendingList });
  } catch (error) {
    console.error("Error fetching pending outpasses:", error);
    res.status(500).json({ success: false, message: "Failed to fetch pending requests." });
  }
});

// --- Start Server ---
app.listen(PORT, () => {
  console.log(? Backend server running on port );
});
