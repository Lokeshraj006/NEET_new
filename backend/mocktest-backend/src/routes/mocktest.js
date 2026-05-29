const express = require('express');
const { pool } = require('../db');

const router = express.Router();

function normalizeCorrectAnswer(value) {
  const text = String(value || '').trim().toUpperCase();
  if (['A', 'B', 'C', 'D'].includes(text)) {
    return text;
  }
  const numeric = Number.parseInt(text, 10);
  if (Number.isInteger(numeric) && numeric >= 1 && numeric <= 4) {
    return ['A', 'B', 'C', 'D'][numeric - 1];
  }
  return '';
}

router.get('/:setNumber', async (req, res, next) => {
  const setNumber = Number.parseInt(req.params.setNumber, 10);
  if (!Number.isInteger(setNumber) || setNumber <= 0) {
    return res.status(400).json({
      detail: 'setNumber must be a positive integer.',
    });
  }

  try {
    const [rows] = await pool.query(
      `SELECT qno, subject, topic, question, optionA, optionB, optionC, optionD, correctAnswer, setNumber
       FROM questions
       WHERE setNumber = ?
       ORDER BY qno ASC`,
      [setNumber],
    );

    if (!rows.length) {
      return res.status(404).json({
        detail: `No questions found for set ${setNumber}.`,
      });
    }

    return res.json(
      rows.map((row) => ({
        qno: Number(row.qno),
        subject: row.subject,
        topic: row.topic,
        question: row.question,
        optionA: row.optionA,
        optionB: row.optionB,
        optionC: row.optionC,
        optionD: row.optionD,
        correctAnswer: normalizeCorrectAnswer(row.correctAnswer),
      })),
    );
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
